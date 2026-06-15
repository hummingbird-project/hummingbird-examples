import AsyncHTTPClient
import Configuration
import Foundation
import Hummingbird
import HummingbirdAuth
import Logging
import OAuthKit

struct OIDCController {
    let client: OpenIDConnectClient

    init(config: ConfigReader, logger: Logger) async throws {
        let discoveryService = OpenIDDiscoveryService(httpClient: HTTPClient.shared)

        guard let clientID = config.string(forKey: "client_id") else { fatalError("No client id provided") }
        guard let clientSecret = config.string(forKey: "client_secret") else { fatalError("No client secret provided") }
        guard let discoveryURL = config.string(forKey: "discovery_url") else { fatalError("No discovery URL provided") }
        guard let redirectURI = config.string(forKey: "redirect_uri") else { fatalError("No redirect URI provided") }

        // Fetch configuration from discovery endpoint
        let configuration = try await discoveryService.discover(url: discoveryURL)

        self.client = try await OpenIDConnectClient(
            httpClient: HTTPClient.shared,
            clientID: clientID,
            clientSecret: clientSecret,
            configuration: configuration,
            redirectURI: redirectURI,
            logger: logger
        )
    }

    var routes: RouteCollection<AppRequestContext> {
        let routes = RouteCollection(context: AppRequestContext.self)
        routes.get("/auth/oidc", use: getProvider)
        routes.get("/auth/oidc-redirect", use: redirect)
        routes.get("/auth/oidc-logout", use: logout)
        return routes
    }

    func getProvider(_ request: Request, context: AppRequestContext) async throws -> Response {
        let state = UUID().uuidString
        let nonce = UUID().uuidString
        let authURL = try client.generateAuthorizationURL(
            state: state,
            additionalParameters: ["nonce": nonce],
            scopes: ["email", "openid", "profile"]
        )

        // Store OAuth state in session
        context.sessions.setSession(.oidc(.init(state: state, nonce: nonce)))

        return .redirect(to: authURL.absoluteString, type: .normal)
    }

    func redirect(_ request: Request, context: AppRequestContext) async throws -> Response {
        guard let session = context.sessions.session?.oidcSession else { throw HTTPError(.badRequest) }
        let queryParameters = request.uri.queryParameters
        guard session.state == queryParameters.get("state") else { throw HTTPError(.badRequest, message: "Invalid state parameter") }
        guard let code = queryParameters.get("code") else { throw HTTPError(.badRequest, message: "Authorization code required") }
        // Exchange authorization code for tokens
        let (response, claims) = try await client.exchangeCode(code: code)

        guard let sub = claims.sub?.value else { throw HTTPError(.internalServerError) }
        guard session.nonce == claims.nonce else { throw HTTPError(.badRequest) }
        context.sessions.setSession(
            .authenticated(
                .init(
                    id: sub,
                    name: claims.name ?? "No name",
                    accessToken: response.accessToken,
                    idToken: response.idToken,
                    refreshToken: response.refreshToken
                )
            )
        )
        return .redirect(to: "/", type: .normal)
    }

    func logout(_ request: Request, context: AppRequestContext) async throws -> Response {
        context.sessions.clearSession()
        return .redirect(to: "/", type: .normal)
    }
}
