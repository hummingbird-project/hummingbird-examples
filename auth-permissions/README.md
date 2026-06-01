# auth-permissions

A Hummingbird example demonstrating **role-based and permission-based access control** (RBAC) using `HummingbirdAuth`. Users carry a set of coarse-grained *roles* and fine-grained *permissions*, both stored as integer bitmasks. Authorization is enforced with `RolePolicy`, `PermissionPolicy`, and the `anyOf` combinator.

## Concepts

### Roles (`Role` OptionSet)

| Bit | Constant | Meaning |
|-----|----------|---------|
| 1 | `.admin` | Can delete any post; access the admin panel |
| 2 | `.editor` | Can create posts |
| 4 | `.moderator` | Cosmetic label |
| 8 | `.reader` | Default role for new web sign-ups |

Roles are combined with standard `OptionSet` syntax — `[.admin, .editor]` — and persisted as a single `Int32` bitmask column (`roles_mask`).

### Permissions (`Permission` OptionSet)

| Bit | Constant | Guards |
|-----|----------|--------|
| 1 | `.postsRead` | (informational; list is currently public) |
| 2 | `.postsWrite` | `POST /posts` |
| 4 | `.postsDelete` | `DELETE /posts/:id` |

Permissions work the same way as roles: combined with `OptionSet`, persisted as `permissions_mask`.

### Policy combinators

```
anyOf { RolePolicy(.admin); PermissionPolicy(.postsDelete) }
```

`anyOf` grants access if **at least one** contained policy passes. The delete route therefore accepts either the `admin` role or the `postsDelete` permission — a moderator with `postsDelete` can delete without being admin.

### Authorization middleware chain

Each protected route group uses `addMiddleware` to compose `BasicAuthenticator` (credential verification) and the relevant policy into a single existential:

```swift
group.group().addMiddleware {
    BasicAuthenticator { username, _ in ... }
    AuthorizationPolicyMiddleware(PermissionPolicy(.postsWrite))
}.post(use: create)
```

---

## Running

```sh
cd auth-permissions
swift run App
```

The database migrates automatically on first boot. Open http://localhost:8080 to use the web UI.

To run only the JSON API (no browser needed):

```sh
# Create a user (admin + all permissions)
curl -X PUT http://localhost:8080/user \
  -H 'Content-Type: application/json' \
  -d '{"name":"alice","password":"secret","roles":15,"permissions":7}'

# List posts (public)
curl http://localhost:8080/posts

# Create a post
curl -X POST http://localhost:8080/posts \
  -u alice:secret \
  -H 'Content-Type: application/json' \
  -d '{"title":"Hello","body":"World"}'
```

`roles` and `permissions` are raw `Int32` bitmask values (sum of the bits above).

---

## Routes

### Web UI

Served as server-rendered HTML via Mustache templates. Session state is stored in SQLite via `FluentPersistDriver`.

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/login` | public | Login page |
| `POST` | `/login` | public | Submit credentials; sets session cookie |
| `GET` | `/signup` | public | Sign-up page |
| `POST` | `/signup` | public | Create account (first user becomes admin) |
| `POST` | `/logout` | public | Clear session cookie |
| `GET` | `/` | session | Posts list; shows Create form if `postsWrite`, Delete buttons if `postsDelete` or `admin` |
| `POST` | `/web/posts` | session + `postsWrite` | Create a post, redirect to `/` |
| `POST` | `/web/posts/:id/delete` | session + (`admin` or `postsDelete`) | Delete a post, redirect to `/` |
| `GET` | `/admin` | session + `admin` role | User management table (redirects to `/` otherwise) |
| `POST` | `/admin/users/:id/roles` | session + `admin` role | Update a user's roles and permissions via checkboxes |

> **Bootstrap**: the very first account created through `/signup` automatically receives
> `[.admin, .editor, .reader]` roles and `[.postsRead, .postsWrite, .postsDelete]` permissions
> so there is always someone who can manage other users.

### JSON API

Uses HTTP Basic authentication. Existing API routes are preserved alongside the web UI.

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `PUT` | `/user` | public | Create a user with explicit `roles`/`permissions` bitmasks |
| `GET` | `/posts` | public | List all posts |
| `POST` | `/posts` | Basic + `postsWrite` | Create a post |
| `DELETE` | `/posts/:id` | Basic + (`admin` role **or** `postsDelete`) | Delete a post |
| `GET` | `/admin/users` | Basic + `admin` role | List all users |

---

## Data model

```
User
├── id: UUID
├── name: String (unique)
├── passwordHash: String?
├── rolesMask: Int32      ← OptionSet bitmask
└── permissionsMask: Int32 ← OptionSet bitmask

Post
├── id: UUID
├── title: String
└── body: String
```

---

## Testing

```sh
swift test
```

Tests exercise the JSON API routes with Basic authentication and in-memory SQLite. The web UI is not covered by automated tests.
