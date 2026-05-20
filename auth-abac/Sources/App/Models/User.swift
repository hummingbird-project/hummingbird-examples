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
import HummingbirdAuth
import HummingbirdBasicAuth

// MARK: - Role & Permission enums

/// Coarse-grained roles assigned to a user.
/// Raw values are the strings persisted in the `roles` column.
enum Role: String, Hashable, Sendable {
    case admin
}

/// Fine-grained permissions assigned to a user.
/// Raw values are the strings persisted in the `permissions` column.
enum Permission: String, Hashable, Sendable {
    case documentsCreate = "documents:create"
    case documentsRead = "documents:read"
    case documentsWrite = "documents:write"
}

// MARK: - User model

/// A user with ABAC subject attributes: department, clearance level, roles, and permissions.
///
/// - `department`: organisational unit (e.g. "engineering", "finance"). Used to
///   scope document access to users within the same department.
/// - `clearanceLevel`: numeric sensitivity threshold (0 = public, 1 = internal,
///   2 = confidential, 3 = restricted). Must be >= a document's `classification`
///   for access to be granted.
/// - `rolesList` / `permissionsList`: comma-separated strings powering
///   ``RoleProviding`` and ``PermissionProviding`` conformances.
final class User: Model, PasswordAuthenticatable, RoleProviding, PermissionProviding, @unchecked Sendable {
    static let schema = "user"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @OptionalField(key: "password_hash")
    var passwordHash: String?

    /// Organisational department — a subject attribute used in department-scope policies.
    @Field(key: "department")
    var department: String

    /// Numeric clearance level (0–3). Must meet or exceed a document's classification.
    @Field(key: "clearance_level")
    var clearanceLevel: Int

    /// Comma-separated roles, e.g. `"admin,editor"`.
    @Field(key: "roles")
    var rolesList: String

    /// Comma-separated permissions, e.g. `"documents:create,documents:read"`.
    @Field(key: "permissions")
    var permissionsList: String

    init() {}

    init(
        id: UUID? = nil,
        name: String,
        passwordHash: String?,
        department: String,
        clearanceLevel: Int,
        rolesList: String = "",
        permissionsList: String = ""
    ) {
        self.id = id
        self.name = name
        self.passwordHash = passwordHash
        self.department = department
        self.clearanceLevel = clearanceLevel
        self.rolesList = rolesList
        self.permissionsList = permissionsList
    }

    // MARK: - RoleProviding

    var roles: Set<Role> {
        Set(rolesList.split(separator: ",").compactMap { Role(rawValue: String($0)) })
    }

    // MARK: - PermissionProviding

    var permissions: Set<Permission> {
        Set(permissionsList.split(separator: ",").compactMap { Permission(rawValue: String($0)) })
    }
}

// MARK: - Request / Response types

struct CreateUserRequest: Decodable {
    let name: String
    let password: String
    let department: String
    let clearanceLevel: Int
    let roles: [String]
    let permissions: [String]
}

struct UserResponse: ResponseCodable {
    let id: UUID?
    let name: String
    let department: String
    let clearanceLevel: Int
    let roles: [String]
    let permissions: [String]

    init(from user: User) {
        self.id = user.id
        self.name = user.name
        self.department = user.department
        self.clearanceLevel = user.clearanceLevel
        self.roles = user.roles.map(\.rawValue).sorted()
        self.permissions = user.permissions.map(\.rawValue).sorted()
    }
}
