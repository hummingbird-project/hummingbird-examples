import Hummingbird
import Mustache

/// Generates an HTML error page for any error thrown downstream.
struct ErrorPageMiddleware<Context: RequestContext>: RouterMiddleware {
    let errorTemplate: MustacheTemplate
    let mustacheLibrary: MustacheLibrary

    func handle(
        _ request: Request,
        context: Context,
        next: (Request, Context) async throws -> Response
    ) async throws -> Response {
        do {
            return try await next(request, context)
        } catch {
            let values: [String: Any]
            let status: HTTPResponse.Status
            if let error = error as? HTTPError {
                status = error.status
                values = [
                    "statusCode": "\(error.status.code) \(error.status.reasonPhrase)",
                    "message": error.body ?? "",
                ]
            } else {
                status = .internalServerError
                values = [
                    "statusCode": "500 Internal Server Error",
                    "message": "\(error)",
                ]
            }
            let html = self.errorTemplate.render(values, library: self.mustacheLibrary)
            var response = try HTML(html: html).response(from: request, context: context)
            response.status = status
            return response
        }
    }
}
