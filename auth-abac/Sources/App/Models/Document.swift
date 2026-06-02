//===----------------------------------------------------------------------===//
//
// This source file is part of the Hummingbird server framework project
//
// Copyright (c) 2021-2024 the Hummingbird authors
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

/// A document with ABAC resource attributes: department, classification, and owner.
///
/// - `department`: must match the requesting user's department (unless admin).
/// - `classification`: minimum clearance level required to read (0 = public,
///   1 = internal, 2 = confidential, 3 = restricted).
/// - `ownerID`: UUID of the user who created the document; only the owner (or
///   an admin) may update it.
final class Document: Model, @unchecked Sendable {
    static let schema = "document"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String

    @Field(key: "content")
    var content: String

    /// Resource attribute: owning department.
    @Field(key: "department")
    var department: String

    /// Resource attribute: minimum clearance level needed to read this document.
    /// 0 = public, 1 = internal, 2 = confidential, 3 = restricted.
    @Field(key: "classification")
    var classification: Int

    /// Resource attribute: the user who created this document.
    @Field(key: "owner_id")
    var ownerID: UUID

    init() {}

    init(
        id: UUID? = nil,
        title: String,
        content: String,
        department: String,
        classification: Int,
        ownerID: UUID
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.department = department
        self.classification = classification
        self.ownerID = ownerID
    }
}

// MARK: - Request / Response types

struct CreateDocumentRequest: Decodable {
    let title: String
    let content: String
    let department: String
    let classification: Int
}

struct UpdateDocumentRequest: Decodable {
    let title: String?
    let content: String?
}

struct DocumentResponse: ResponseCodable {
    let id: UUID?
    let title: String
    let content: String
    let department: String
    let classification: Int
    let ownerID: UUID

    init(from document: Document) {
        self.id = document.id
        self.title = document.title
        self.content = document.content
        self.department = document.department
        self.classification = document.classification
        self.ownerID = document.ownerID
    }
}
