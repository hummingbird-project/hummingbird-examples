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

// MARK: - Role & Permission OptionSets
//
// Using OptionSet means roles and permissions are stored as a single Int32
// bitmask column per user. Membership checks become bitwise operations and
// RolePolicy / PermissionPolicy work unchanged because OptionSet conforms
// to SetAlgebra — the constraint required by RoleProviding / PermissionProviding.

/// Coarse-grained roles. Each case is a single bit; combinations are formed
/// with standard OptionSet syntax: `[.admin, .editor]`.
struct Role: OptionSet, Sendable {
    let rawValue: Int32
    static let admin = Role(rawValue: 1 << 0)
    static let editor = Role(rawValue: 1 << 1)
    static let moderator = Role(rawValue: 1 << 2)
    static let reader = Role(rawValue: 1 << 3)
}

/// Fine-grained permissions. Combine freely: `[.postsRead, .postsWrite]`.
struct Permission: OptionSet, Sendable {
    let rawValue: Int32
    static let postsRead = Permission(rawValue: 1 << 0)
    static let postsWrite = Permission(rawValue: 1 << 1)
    static let postsDelete = Permission(rawValue: 1 << 2)
}

// MARK: - User model

final class User: Model, PasswordAuthenticatable, RoleProviding, PermissionProviding, @unchecked Sendable {
    static let schema = "user"

    @ID(key: .id) var id: UUID?
    @Field(key: "name") var name: String
    @OptionalField(key: "password_hash") var passwordHash: String?

    /// Bitmask persisted as a single Int32 column.
    @Field(key: "roles_mask") var rolesMask: Int32

    /// Bitmask persisted as a single Int32 column.
    @Field(key: "permissions_mask") var permissionsMask: Int32

    init() {}

    init(
        id: UUID? = nil,
        name: String,
        passwordHash: String?,
        roles: Role,
        permissions: Permission
    ) {
        self.id = id
        self.name = name
        self.passwordHash = passwordHash
        self.rolesMask = roles.rawValue
        self.permissionsMask = permissions.rawValue
    }

    // MARK: - RoleProviding / PermissionProviding
    // OptionSet.Element == Self, so contains() is a single bitwise AND.

    var roles: Role { Role(rawValue: rolesMask) }
    var permissions: Permission { Permission(rawValue: permissionsMask) }
}

// MARK: - Request / Response types

struct CreateUserRequest: Decodable {
    let name: String
    let password: String?
    let roles: Int32
    let permissions: Int32
}

struct UserResponse: ResponseCodable {
    let id: UUID?
    let name: String
    let roles: Int32
    let permissions: Int32

    init(from user: User) {
        self.id = user.id
        self.name = user.name
        self.roles = user.rolesMask
        self.permissions = user.permissionsMask
    }
}
