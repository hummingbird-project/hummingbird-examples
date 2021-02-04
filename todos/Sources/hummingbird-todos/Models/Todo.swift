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

    init() { }

    init(id: UUID? = nil, title: String, order: Int?) {
        self.id = id
        self.title = title
        self.order = order
    }
}
