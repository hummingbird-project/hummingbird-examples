import Foundation
import Hummingbird

struct Todo: HBResponseCodable {
    var id: UUID?

    var title: String

    var order: Int?

    var url: String?

    var completed: Bool?

    init(id: UUID? = nil, title: String, order: Int?, url: String?, completed: Bool?) {
        self.id = id
        self.title = title
        self.order = order
        self.url = url
        self.completed = completed
    }

    mutating func update(from edit: EditTodo) {
        if let title = edit.title {
            self.title = title
        }
        if let order = edit.order {
            self.order = order
        }
        if let completed = edit.completed {
            self.completed = completed
        }
    }

    mutating func update(from todo: Todo) {
        self.title = todo.title
        if let order = todo.order {
            self.order = order
        }
        if let completed = todo.completed {
            self.completed = completed
        }
    }
}

struct EditTodo: HBResponseCodable {
    var id: UUID?
    var title: String?
    var order: Int?
    var completed: Bool?
}
