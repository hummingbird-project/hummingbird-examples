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
    case editor
    case moderator
    case reader
}

/// Fine-grained permissions assigned to a user.
/// Raw values are the strings persisted in the `permissions` column.
enum Permission: String, Hashable, Sendable {
    case postsRead = "posts:read"
    case postsWrite = "posts:write"
    case postsDelete = "posts:delete"
}

// MARK: - User model

/// Database description of a user
final class User: Model, PasswordAuthenticatable, RoleProviding, PermissionProviding, @unchecked Sendable {
    static let schema = "user"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @OptionalField(key: "password_hash")
    var passwordHash: String?

    /// Comma-separated list of roles, e.g. "admin,editor"
    @Field(key: "roles")
    var rolesList: String

    /// Comma-separated list of permissions, e.g. "posts:read,posts:write"
    @Field(key: "permissions")
    var permissionsList: String

    init() {}

    init(
        id: UUID? = nil,
        name: String,
        passwordHash: String?,
        rolesList: String,
        permissionsList: String
    ) {
        self.id = id
        self.name = name
        self.passwordHash = passwordHash
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

/// Request body for creating a new user
struct CreateUserRequest: Decodable {
    let name: String
    let password: String?
    let roles: [String]
    let permissions: [String]

    init(name: String, password: String?, roles: [String] = [], permissions: [String] = []) {
        self.name = name
        self.password = password
        self.roles = roles
        self.permissions = permissions
    }
}

/// User encoded into an HTTP response
struct UserResponse: ResponseCodable {
    let id: UUID?
    let name: String
    let roles: [String]
    let permissions: [String]

    init(from user: User) {
        self.id = user.id
        self.name = user.name
        self.roles = user.roles.map(\.rawValue).sorted()
        self.permissions = user.permissions.map(\.rawValue).sorted()
    }
}
