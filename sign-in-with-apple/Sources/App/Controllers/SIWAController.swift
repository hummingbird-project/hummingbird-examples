import ExtrasBase64
import Hummingbird
import JWTKit
import Mustache

struct SIWAController {
    let signInTemplate: MustacheTemplate
    let mustacheLibrary: MustacheLibrary
    let siwa: SignInWithApple

    init(signInWithApple: SignInWithApple, mustacheLibrary: MustacheLibrary) {
        self.siwa = signInWithApple
        self.mustacheLibrary = mustacheLibrary
        self.signInTemplate = mustacheLibrary.getTemplate(named: "index")!
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
        _ = try await siwa.verify(appleAuthResponse.idToken)
        return try await siwa.requestAccessToken(appleAuthResponse: appleAuthResponse)
    }
}
