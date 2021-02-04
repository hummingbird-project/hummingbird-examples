import FluentKit
import Foundation
import Hummingbird

final class Todo: Model, HBResponseCodable {
    static let schema = "todos"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String

    @Field(key: "order")
    var order: Int?

    @Field(key: "url")
    var url: String?

    @Field(key: "completed")
    var completed: Bool?

    init() { }

    init(id: UUID? = nil, title: String, order: Int?, url: String?, completed: Bool?) {
        self.id = id
        self.title = title
        self.order = order
        self.url = url
        self.completed = completed
    }

    func update(from: Todo) {
        self.title = from.title
        if let order = from.order {
            self.order = order
        }
        if let completed = from.completed {
            self.completed = completed
        }
    }
}
