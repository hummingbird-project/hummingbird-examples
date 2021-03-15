import Hummingbird

struct HTML: HBResponseGenerator {
    let html: String

    public func response(from request: HBRequest) throws -> HBResponse {
        let buffer = request.allocator.buffer(string: self.html)
        return .init(status: .ok, headers: ["content-type": "text/html"], body: .byteBuffer(buffer))
    }
}

struct WebController {
    func input(request: HBRequest) -> HTML {
        let html = request.mustache.render((), withTemplate: "enter-details")!
        return HTML(html: html)
    }

    func post(request: HBRequest) throws -> HTML {
        guard let user = try? request.decode(as: User.self) else { throw HBHTTPError(.badRequest) }
        let html = request.mustache.render(user, withTemplate: "details-entered")!
        return HTML(html: html)
    }
}
