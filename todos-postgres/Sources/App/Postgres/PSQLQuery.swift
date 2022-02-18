import Foundation
import PostgresNIO

extension PSQLQuery {
    init<V1: PSQLEncodable>(_ query: String, _ value1: V1, context: PSQLEncodingContext<JSONEncoder>) throws {
        self.init(stringLiteral: query)
        try appendBinding( value1, context: context)
    }

    init<V1: PSQLEncodable, V2: PSQLEncodable>(_ query: String, _ value1: V1, _ value2: V2, context: PSQLEncodingContext<JSONEncoder>) throws {
        self.init(stringLiteral: query)
        try appendBinding(value1, context: context)
        try appendBinding(value2, context: context)
    }

    init<V1: PSQLEncodable, V2: PSQLEncodable, V3: PSQLEncodable>(_ query: String, _ value1: V1, _ value2: V2, _ value3: V3, context: PSQLEncodingContext<JSONEncoder>) throws {
        self.init(stringLiteral: query)
        try appendBinding(value1, context: context)
        try appendBinding(value2, context: context)
        try appendBinding(value3, context: context)
    }

    init<V1: PSQLEncodable, V2: PSQLEncodable, V3: PSQLEncodable, V4: PSQLEncodable>(_ query: String, _ value1: V1, _ value2: V2, _ value3: V3, _ value4: V4, context: PSQLEncodingContext<JSONEncoder>) throws {
        self.init(stringLiteral: query)
        try appendBinding(value1, context: context)
        try appendBinding(value2, context: context)
        try appendBinding(value3, context: context)
        try appendBinding(value4, context: context)
    }
}