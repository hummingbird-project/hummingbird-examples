import Hummingbird
import HummingbirdAuth

extension AccessToken: HBAuthenticatable {}

struct BearerAuthenticator: HBAuthenticator {
  func authenticate(request: HBRequest) -> EventLoopFuture<AccessToken?> {
    guard let bearer = request.authBearer else { return request.success(nil) }
    print(bearer)
    return "hello"
  }
  // func authenticate(request: HBRequest) -> EventLoopFuture<User?> {
  //   guard let basic = request.auth. else { return request.success(nil) }
  //   // let authorization = request.headers["Authorization"].first
  //   // guard let user = request.auth.get(User.self) else { throw HBHTTPError(.unauthorized) }
  //   // return user
  // }
}
