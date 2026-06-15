import Hummingbird
import HummingbirdAuth
import Mustache

/// Type wrapping HTML code. Will convert to HBResponse that includes the correct
/// content-type header
struct HTML: ResponseGenerator {
    let html: String

    public func response(from request: Request, context: some RequestContext) throws -> Response {
        let buffer = ByteBuffer(string: self.html)
        return .init(status: .ok, headers: [.contentType: "text/html"], body: .init(byteBuffer: buffer))
    }
}

struct WebController {
    typealias Context = AppRequestContext

    let indexTemplate: MustacheTemplate

    init(library: MustacheLibrary) {
        guard let indexTemplate = library.getTemplate(named: "index.html") else { fatalError() }
        self.indexTemplate = indexTemplate
    }

    var routes: RouteCollection<AppRequestContext> {
        let routes = RouteCollection(context: AppRequestContext.self)
        routes.get("/", use: home)
        return routes
    }

    func home(request: Request, context: Context) async throws -> HTML {
        var mustacheContext: [String: String] = [:]
        if let authenticated = context.sessions.session?.authenticatedState {
            mustacheContext["name"] = authenticated.name
        }
        return HTML(html: indexTemplate.render(mustacheContext))
    }
}
