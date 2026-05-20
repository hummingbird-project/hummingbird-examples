# auth-permissions

A Hummingbird example demonstrating role-based access control (RBAC) and fine-grained permission-based authorization using the `HummingbirdAuthorization` package.

## Overview

This example implements a simple blog API with:
- **Users** that carry roles (e.g. `admin`, `editor`) and permissions (e.g. `posts:write`, `posts:delete`)
- **Posts** that can be listed, created, and deleted
- Route protection using `RolePolicy`, `PermissionPolicy`, and the `AnyOf` combinator

## Endpoints

| Method | Path | Auth | Notes |
|--------|------|------|-------|
| `PUT` | `/user` | public | Create a user account (roles & permissions in body) |
| `GET` | `/posts` | public | List all posts |
| `POST` | `/posts` | `posts:write` permission | Create a post |
| `DELETE` | `/posts/:id` | `admin` role **or** `posts:delete` permission | Delete a post |
| `GET` | `/admin/users` | `admin` role | List all users |

## Running

```sh
swift run App --migrate
```

## Testing

```sh
swift test
```
