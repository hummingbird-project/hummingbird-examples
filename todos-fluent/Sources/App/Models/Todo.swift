//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2021 the Hummingbird authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See hummingbird/CONTRIBUTORS.txt for the list of Hummingbird authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import FluentKit
import Foundation
import Hummingbird

/// Database description of a Todo
final class Todo: Model, ResponseCodable, @unchecked Sendable {
    static let schema = "todos"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String

    @Field(key: "url")
    var url: String?

    @Field(key: "completed")
    var completed: Bool

    init() {}

    init(id: UUID? = nil, title: String, url: String? = nil, completed: Bool = false) {
        self.id = id
        self.title = title
        self.url = url
        self.completed = completed
    }

    func update(title: String? = nil, completed: Bool? = nil) {
        if let title = title {
            self.title = title
        }
        if let completed = completed {
            self.completed = completed
        }
    }
}
