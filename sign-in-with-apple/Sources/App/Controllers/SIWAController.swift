import ExtrasBase64
import FluentKit
import Foundation
import Hummingbird
import HummingbirdFluent
import JWTKit
import Mustache

struct SIWAController {
    let signInTemplate: MustacheTemplate
    let mustacheLibrary: MustacheLibrary
    let siwa: SignInWithApple
    let fluent: Fluent

    init(signInWithApple: SignInWithApple, mustacheLibrary: MustacheLibrary, fluent: Fluent) {
        self.siwa = signInWithApple
        self.mustacheLibrary = mustacheLibrary
        self.signInTemplate = mustacheLibrary.getTemplate(named: "index")!
        self.fluent = fluent
    }

    var routes: RouteCollection<AppRequestContext> {
        let routes = RouteCollection(context: AppRequestContext.self)
        routes.get("/", use: home)
        routes.post("siwa-redirect", use: siwaRedirect)
        return routes
    }

    func home(request: Request, context: AppRequestContext) async throws -> HTML {
        let state = String(_base64Encoding: (0..<16).map { _ in UInt8.random(in: 0...255) })
        context.sessions.setSession(.init(state: state), expiresIn: .seconds(300))
        let context: [String: Any] = [
            "clientId": siwa.siwaId,
            "scope": "name email",
            "redirectURI": siwa.redirectURL,
            "state": state,
            "usePopup": false,
        ]
        return HTML(signInTemplate.render(context, library: mustacheLibrary))
    }

    func siwaRedirect(request: Request, context: AppRequestContext) async throws -> String {
        let appleAuthResponse = try await request.decode(as: SignInWithApple.AppleAuthResponse.self, context: context)
        let state = context.sessions.session?.state ?? ""
        guard state == appleAuthResponse.state else { throw HTTPError(.badRequest) }
        let token = try await siwa.verify(appleAuthResponse.idToken)
        // do we already have a user with this id
        let siwaToken = try await SIWAToken.query(on: fluent.db())
            .with(\.$user)
            .filter(\.$token == token.subject.value)
            .first()
        if let siwaToken {
            // update email if user decides to hide email
            if let email = token.email, email != siwaToken.user.email {
                siwaToken.user.email = email
                try await siwaToken.user.update(on: fluent.db())
            }
            return try await siwa.requestAccessToken(appleAuthResponse: appleAuthResponse)
        } else if let userString = appleAuthResponse.user {
            let userData = ByteBuffer(string: userString)
            let userInfo = try JSONDecoder().decode(SignInWithApple.AppleAuthResponse.User.self, from: userData)
            let user = User(name: "\(userInfo.name.firstName) \(userInfo.name.lastName)", email: userInfo.email)
            try await user.create(on: fluent.db())
            let siwaToken = SIWAToken(token: token.subject.value, userID: try user.requireID())
            try await siwaToken.create(on: fluent.db())
            return try await siwa.requestAccessToken(appleAuthResponse: appleAuthResponse)
        } else {
            // User isn't in database, and we havent been supplied user info so throw error
            throw HTTPError(.unauthorized)
        }
    }
}
