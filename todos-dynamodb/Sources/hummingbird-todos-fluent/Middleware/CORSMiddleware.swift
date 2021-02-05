import Hummingbird

struct CORSMiddleware: HBMiddleware {
    func apply(to request: HBRequest, next: HBResponder) -> EventLoopFuture<HBResponse> {
        if request.method == .OPTIONS {
            let headers: HTTPHeaders = [
                "access-control-allow-origin": "*",
                "access-control-allow-headers": "content-type",
                "access-control-allow-methods": "OPTIONS, GET, POST, DELETE, PATCH"
            ]
            return request.success(HBResponse(status: .noContent, headers: headers, body: .empty))
        } else {
            return next.respond(to: request).map { response in
                response.headers.replaceOrAdd(name: "access-control-allow-origin", value: "*")
                response.headers.replaceOrAdd(name: "access-control-allow-headers", value: "content-type")
                response.headers.replaceOrAdd(name: "access-control-allow-methods", value: "OPTIONS, GET, POST, DELETE, PATCH")
                return response
            }
        }
    }
}
