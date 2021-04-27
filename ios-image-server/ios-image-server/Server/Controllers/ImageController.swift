import Foundation
import Hummingbird

struct ImageController {
    func addRoutes(to router: HBRouterMethods) {
        router.get("/assets/:index", use: GetImageHandler.self)
    }

    /// Get image route hander
    struct GetImageHandler: HBRouteHandler {
        let index: Int
        let width: Double
        let height: Double

        init(from request: HBRequest) throws {
            self.index = try request.parameters.require("index", as: Int.self)
            self.width = request.uri.queryParameters.get("width", as: Double.self) ?? 1024
            self.height = request.uri.queryParameters.get("height", as: Double.self) ?? 1024
        }

        func handle(request: HBRequest) -> EventLoopFuture<ImageData> {
            let promise = request.eventLoop.makePromise(of: ImageData.self)
            request.application.photoLibrary.loadPhoto(index: self.index, targetSize: .init(width: self.width, height: self.height)) { result in
                promise.completeWith(result.map { .init(data: $0) })
            }
            return promise.futureResult
        }
    }
}
