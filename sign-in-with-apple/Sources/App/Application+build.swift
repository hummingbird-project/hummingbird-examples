import Foundation
import Hummingbird
import HummingbirdAuth
import Logging
import Mustache

/// Application arguments protocol. We use a protocol so we can call
/// `buildApplication` inside Tests as well as in the App executable.
/// Any variables added here also have to be added to `App` in App.swift and
/// `TestArguments` in AppTest.swift
public protocol AppArguments {
    var hostname: String { get }
    var port: Int { get }
    var logLevel: Logger.Level? { get }
}

struct Session: Codable {
    let state: String
}

struct User: Codable {
    let username: String
    let email: String
}

// Request context used by application
typealias AppRequestContext = BasicSessionRequestContext<Session, User>

///  Build application
/// - Parameter arguments: application arguments
public func buildApplication(_ arguments: some AppArguments) async throws -> some ApplicationProtocol {
    let environment = try await Environment().merging(with: .dotEnv())
    let logger = {
        var logger = Logger(label: "SIWA")
        logger.logLevel =
            arguments.logLevel ?? environment.get("LOG_LEVEL").flatMap { Logger.Level(rawValue: $0) } ?? .info
        return logger
    }()
    let keyValueStore = MemoryPersistDriver()

    let router = try await buildRouter(
        environment: environment,
        keyValueStore: keyValueStore
    )
    let app = Application(
        router: router,
        configuration: .init(
            address: .hostname(arguments.hostname, port: arguments.port),
            serverName: "SIWA"
        ),
        logger: logger
    )
    return app
}

/// Build router
func buildRouter(
    environment: Environment,
    keyValueStore: some PersistDriver
) async throws -> Router<AppRequestContext> {
    // load mustache template library
    let mustacheLibrary = try await MustacheLibrary(directory: Bundle.module.resourcePath!)
    // set Sign in with Apple
    let signInWithApple = try await SignInWithApple(
        siwaId: environment.require("SIWA_SERVICE_ID"),
        teamId: environment.require("SIWA_TEAM_ID"),
        jwkId: environment.require("SIWA_JWK_ID"),
        redirectURL: environment.require("SIWA_REDIRECT_URL"),
        key: environment.require("SIWA_KEY"),
        httpClient: .shared
    )

    let router = Router(context: AppRequestContext.self)
    // Add middleware
    router.addMiddleware {
        // logging middleware
        LogRequestsMiddleware(.info)
        // file middleware
        FileMiddleware()
        // session middleware
        SessionMiddleware(storage: keyValueStore)
    }
    router.addRoutes(SIWAController(signInWithApple: signInWithApple, mustacheLibrary: mustacheLibrary).routes)
    return router
}
