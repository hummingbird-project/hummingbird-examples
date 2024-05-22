import Foundation
import Hummingbird

struct Todo {
    // Todo ID
    var id: UUID
    // Title
    var title: String
    // Order number
    var order: Int?
    // URL to get this ToDo
    var url: String
    // Is Todo complete
    var completed: Bool?
}

extension Todo: ResponseEncodable, Decodable, Equatable {}
