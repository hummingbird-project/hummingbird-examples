# auth-abac

A Hummingbird example demonstrating **Attribute-Based Access Control (ABAC)** using `HummingbirdAuth`. Access decisions are made by evaluating *subject attributes* (properties of the requesting user) against *resource attributes* (properties of the document being acted on) and *environment attributes* (e.g. time of day).

## Concepts

### Subject attributes (on `User`)

| Attribute | Type | Role in access decisions |
|-----------|------|--------------------------|
| `department` | `String` | Must match a document's `department` for non-admin read/write |
| `clearanceLevel` | `Int` (0–3) | Must be ≥ a document's `classification` to read content |
| `roles` | comma-separated | `admin` role bypasses department and clearance checks |
| `permissions` | comma-separated | `documents:create/read/write` gate specific operations |

### Resource attributes (on `Document`)

| Attribute | Type | Meaning |
|-----------|------|---------|
| `department` | `String` | Owning department — read/write scoped to same dept |
| `classification` | `Int` (0–3) | Minimum clearance needed: 0=Public, 1=Internal, 2=Confidential, 3=Restricted |
| `ownerID` | `UUID` | Only the owner (or admin) may update the document |

### Policies

| Policy | Passes when |
|--------|-------------|
| `SameDepartmentPolicy` | `user.department == document.department` |
| `SufficientClearancePolicy` | `user.clearanceLevel >= document.classification` |
| `DocumentOwnerPolicy` | `user.id == document.ownerID` |
| `BusinessHoursPolicy` | Current hour is within the configured `allowedDeletionHours` range |

Policies compose with `anyOf` / `allOf`:

```swift
// GET /documents/:id — admin bypass OR (same dept AND sufficient clearance)
anyOf {
    RolePolicy(.admin)
    allOf {
        SameDepartmentPolicy()
        SufficientClearancePolicy()
    }
}

// DELETE /documents/:id — must be admin AND within business hours
allOf {
    RolePolicy(.admin)
    BusinessHoursPolicy(allowedHours: 9..<17)
}
```

### Two-stage identity assembly

The ABAC context carries two identity fields to avoid fetching the document twice:

1. `UserAuthenticatorMiddleware` verifies Basic auth → writes the `User` to `context.authenticatedUser`
2. For collection routes, `UserIdentityMiddleware` promotes `authenticatedUser` into `context.identity` (a `DocumentRequest` with `document: nil`)
3. For document routes, `DocumentResolverMiddleware` fetches the document **once** by `:id` and bundles it with the user into `context.identity`

By the time a policy or handler runs, `context.identity` contains both subject and resource attributes with zero extra database calls.

---

## Running

```sh
cd auth-abac
swift run App
```

The database migrates automatically on first boot. Open http://localhost:8080 to use the web UI.

To explore the JSON API:

```sh
# Create a user (engineering dept, clearance 2, documents:create + read + write)
curl -X PUT http://localhost:8080/user \
  -H 'Content-Type: application/json' \
  -d '{
    "name": "alice",
    "password": "secret",
    "department": "engineering",
    "clearanceLevel": 2,
    "roles": [],
    "permissions": ["documents:create", "documents:read", "documents:write"]
  }'

# Create a document (internal, engineering)
curl -X POST http://localhost:8080/documents \
  -u alice:secret \
  -H 'Content-Type: application/json' \
  -d '{"title":"Spec","content":"...","department":"engineering","classification":1}'

# Read it back
curl http://localhost:8080/documents/<id> -u alice:secret
```

---

## Routes

### Web UI

Server-rendered HTML using Mustache templates. Sessions are persisted in SQLite via `FluentPersistDriver`. The web UI performs its own ABAC logic inline rather than going through the API middleware pipeline.

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| `GET` | `/login` | public | Login page |
| `POST` | `/login` | public | Submit credentials; sets session cookie |
| `GET` | `/signup` | public | Sign-up page (includes department + clearance level fields) |
| `POST` | `/signup` | public | Create account with ABAC subject attributes |
| `POST` | `/logout` | public | Clear session |
| `GET` | `/` | session | Lists documents readable by the current user (same dept + sufficient clearance; all docs for admins) |
| `POST` | `/web/documents` | session | Create a document (department set to user's own dept; owner set to current user) |
| `GET` | `/view/:id` | session | View document; shows clearance-required notice if dept matches but clearance is insufficient; shows Edit form if owner or admin |
| `POST` | `/web/documents/:id/update` | session + owner or admin | Update title and content |

### JSON API

Uses HTTP Basic authentication via `UserAuthenticatorMiddleware`.

| Method | Path | Auth | Policy | Description |
|--------|------|------|--------|-------------|
| `PUT` | `/user` | public | — | Create a user with ABAC attributes |
| `GET` | `/documents` | public | — | List all documents (metadata only) |
| `POST` | `/documents` | Basic | `documents:create` permission | Create a document |
| `GET` | `/documents/:id` | Basic | admin **or** (same dept **and** sufficient clearance) | Read a document |
| `PUT` | `/documents/:id` | Basic | admin **or** owner | Update a document |
| `DELETE` | `/documents/:id` | Basic | admin **and** within `allowedDeletionHours` | Delete a document |

---

## Data model

```
User
├── id: UUID
├── name: String (unique)
├── passwordHash: String?
├── department: String          ← subject attribute
├── clearanceLevel: Int (0–3)   ← subject attribute
├── rolesList: String           ← comma-separated, e.g. "admin"
└── permissionsList: String     ← comma-separated, e.g. "documents:create,documents:read"

Document
├── id: UUID
├── title: String
├── content: String
├── department: String          ← resource attribute
├── classification: Int (0–3)  ← resource attribute
└── ownerID: UUID               ← resource attribute
```

### Clearance / classification scale

| Level | Label | Who can read |
|-------|-------|--------------|
| 0 | Public | Everyone in the same department |
| 1 | Internal | Clearance ≥ 1 |
| 2 | Confidential | Clearance ≥ 2 |
| 3 | Restricted | Clearance = 3 |

---

## Testing

```sh
swift test
```

Tests cover the full JSON API matrix — department matching, clearance thresholds, owner-only update, admin bypass, and business-hours delete — using an in-memory SQLite database. The web UI is not covered by automated tests.
