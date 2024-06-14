import Hummingbird
import HummingbirdAuth
import Logging
import NIOCore

struct TodosAuthRequestContext: AuthRequestContext, RequestContext {
    var coreContext: CoreRequestContext
    var auth: LoginCache

    init(source: Source) {
        self.coreContext = .init(source: source)
        self.auth = .init()
    }

    var requestDecoder: TodosAuthRequestDecoder {
        TodosAuthRequestDecoder()
    }
}
