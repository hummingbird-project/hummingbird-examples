import Foundation
import Hummingbird
import HummingbirdAuth
import Logging
import NIOCore

struct TodosAuthRequestContext: AuthRequestContext, SessionRequestContext, RequestContext {
    var coreContext: CoreRequestContextStorage
    var auth: LoginCache
    var sessions: SessionContext<UUID>

    init(source: Source) {
        self.coreContext = .init(source: source)
        self.auth = .init()
        self.sessions = .init()
    }

    var requestDecoder: TodosAuthRequestDecoder {
        TodosAuthRequestDecoder()
    }
}
