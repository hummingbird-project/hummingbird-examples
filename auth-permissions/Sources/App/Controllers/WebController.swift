import FluentKit
import Foundation
import Hummingbird
import HummingbirdAuth
import HummingbirdBcrypt
import HummingbirdFluent
import Mustache
import NIOPosix

/// Serves the browser-facing HTML pages.
struct WebController {
    typealias Context = AppRequestContext

    let fluent: Fluent
    let sessionAuthenticator: SessionAuthenticator<Context, UserRepository>
    let mustacheLibrary: MustacheLibrary
    let postsTemplate: MustacheTemplate
    let adminTemplate: MustacheTemplate
    let loginTemplate: MustacheTemplate
    let signupTemplate: MustacheTemplate
    let errorTemplate: MustacheTemplate

    init(
        mustacheLibrary: MustacheLibrary,
        fluent: Fluent,
        sessionAuthenticator: SessionAuthenticator<Context, UserRepository>
    ) {
        self.mustacheLibrary = mustacheLibrary
        self.fluent = fluent
        self.sessionAuthenticator = sessionAuthenticator
        guard
            let postsTemplate = mustacheLibrary.getTemplate(named: "posts"),
            let adminTemplate = mustacheLibrary.getTemplate(named: "admin"),
            let loginTemplate = mustacheLibrary.getTemplate(named: "login"),
            let signupTemplate = mustacheLibrary.getTemplate(named: "signup"),
            let errorTemplate = mustacheLibrary.getTemplate(named: "error")
        else {
            preconditionFailure("Failed to load mustache templates from bundle")
        }
        self.postsTemplate = postsTemplate
        self.adminTemplate = adminTemplate
        self.loginTemplate = loginTemplate
        self.signupTemplate = signupTemplate
        self.errorTemplate = errorTemplate
    }

    func addRoutes(to router: Router<Context>) {
        router.group()
            .add(middleware: ErrorPageMiddleware(errorTemplate: errorTemplate, mustacheLibrary: mustacheLibrary))
            // Unauthenticated routes
            .get("/login", use: login)
            .post("/login", use: loginDetails)
            .get("/signup", use: signup)
            .post("/signup", use: signupDetails)
            .post("/logout", use: logout)
            // Authenticated routes
            .add(middleware: sessionAuthenticator)
            .add(middleware: RedirectMiddleware(to: "/login"))
            .get("/", use: home)
            .post("/web/posts", use: createPost)
            .post("/web/posts/:id/delete", use: deletePost)
            .get("/admin", use: admin)
            .post("/admin/users/:id/roles", use: updateUserRoles)
    }

    // MARK: - Auth pages

    func login(request: Request, context: Context) async throws -> HTML {
        HTML(html: loginTemplate.render([:] as [String: Any], library: mustacheLibrary))
    }

    struct LoginDetails: Decodable {
        let name: String
        let password: String
    }

    func loginDetails(request: Request, context: Context) async throws -> Response {
        let details = try await request.decode(as: LoginDetails.self, context: context)
        guard
            let user = try await User.query(on: fluent.db()).filter(\.$name == details.name).first(),
            let hash = user.passwordHash,
            try await NIOThreadPool.singleton.runIfActive({ Bcrypt.verify(details.password, hash: hash) })
        else {
            let html = loginTemplate.render(["failed": true], library: mustacheLibrary)
            var response = try HTML(html: html).response(from: request, context: context)
            response.status = .unauthorized
            return response
        }
        context.sessions.setSession(try user.requireID())
        return .redirect(to: request.uri.queryParameters.get("from") ?? "/", type: .found)
    }

    struct SignupDetails: Decodable {
        let name: String
        let password: String
    }

    func signup(request: Request, context: Context) async throws -> HTML {
        HTML(html: signupTemplate.render([:] as [String: Any], library: mustacheLibrary))
    }

    func signupDetails(request: Request, context: Context) async throws -> Response {
        let details = try await request.decode(as: SignupDetails.self, context: context)
        let db = fluent.db()
        guard try await User.query(on: db).filter(\.$name == details.name).first() == nil else {
            let html = signupTemplate.render(["failed": true], library: mustacheLibrary)
            return try HTML(html: html).response(from: request, context: context)
        }
        let hash = try await NIOThreadPool.singleton.runIfActive { Bcrypt.hash(details.password, cost: 12) }
        // First user to register automatically becomes admin with all permissions —
        // this bootstraps the app so someone can manage roles without using the JSON API.
        let isFirst = try await User.query(on: db).count() == 0
        let user = User(
            name: details.name,
            passwordHash: hash,
            roles: isFirst ? [.admin, .editor, .reader] : .reader,
            permissions: isFirst ? [.postsRead, .postsWrite, .postsDelete] : .postsRead
        )
        try await user.save(on: db)
        return .redirect(to: "/login", type: .found)
    }

    func logout(request: Request, context: Context) async throws -> Response {
        context.sessions.clearSession()
        return .redirect(to: "/login", type: .found)
    }

    // MARK: - Home (posts list)

    struct PostItem {
        let id: String
        let title: String
        let body: String
        let canDelete: Bool
    }

    func home(request: Request, context: Context) async throws -> HTML {
        let user = try context.requireIdentity()
        let posts = try await Post.query(on: fluent.db()).all()
        let canWrite = user.permissions.contains(.postsWrite)
        let canDelete = user.permissions.contains(.postsDelete) || user.roles.contains(.admin)
        let postItems = posts.map { post in
            PostItem(
                id: post.id?.uuidString ?? "",
                title: post.title,
                body: post.body,
                canDelete: canDelete
            )
        }
        let object: [String: Any] = [
            "name": user.name,
            "roleInfo": roleNames(user.roles),
            "isAdmin": user.roles.contains(.admin),
            "canWrite": canWrite,
            "posts": postItems,
        ]
        return HTML(html: postsTemplate.render(object, library: mustacheLibrary))
    }

    struct CreatePostForm: Decodable {
        let title: String
        let body: String
    }

    func createPost(request: Request, context: Context) async throws -> Response {
        let user = try context.requireIdentity()
        guard user.permissions.contains(.postsWrite) else { throw HTTPError(.forbidden) }
        let form = try await request.decode(as: CreatePostForm.self, context: context)
        let post = Post(title: form.title, body: form.body)
        try await post.save(on: fluent.db())
        return .redirect(to: "/", type: .found)
    }

    func deletePost(request: Request, context: Context) async throws -> Response {
        let user = try context.requireIdentity()
        guard user.roles.contains(.admin) || user.permissions.contains(.postsDelete) else {
            throw HTTPError(.forbidden)
        }
        let id = try context.parameters.require("id", as: UUID.self)
        guard let post = try await Post.find(id, on: fluent.db()) else {
            throw HTTPError(.notFound)
        }
        try await post.delete(on: fluent.db())
        return .redirect(to: "/", type: .found)
    }

    // MARK: - Admin page

    /// Per-user row in the admin table — includes individual boolean flags for each
    /// role and permission so Mustache can render `checked` attributes on checkboxes.
    struct UserItem {
        let id: String
        let name: String
        let roleLabel: String
        let permLabel: String
        // Role checkboxes
        let isAdmin: Bool
        let isEditor: Bool
        let isModerator: Bool
        let isReader: Bool
        // Permission checkboxes
        let canRead: Bool
        let canWrite: Bool
        let canDelete: Bool
    }

    func admin(request: Request, context: Context) async throws -> Response {
        let user = try context.requireIdentity()
        guard user.roles.contains(.admin) else {
            return .redirect(to: "/", type: .found)
        }
        let users = try await User.query(on: fluent.db()).all()
        let userItems = users.map { u in
            UserItem(
                id: u.id?.uuidString ?? "",
                name: u.name,
                roleLabel: roleNames(u.roles),
                permLabel: permissionNames(u.permissions),
                isAdmin: u.roles.contains(.admin),
                isEditor: u.roles.contains(.editor),
                isModerator: u.roles.contains(.moderator),
                isReader: u.roles.contains(.reader),
                canRead: u.permissions.contains(.postsRead),
                canWrite: u.permissions.contains(.postsWrite),
                canDelete: u.permissions.contains(.postsDelete)
            )
        }
        let object: [String: Any] = [
            "name": user.name,
            "users": userItems,
        ]
        return try HTML(html: adminTemplate.render(object, library: mustacheLibrary))
            .response(from: request, context: context)
    }

    /// Unchecked HTML checkboxes are not submitted at all, so each field is `String?`.
    /// A non-nil value (typically `"on"`) means the box was checked.
    struct RoleUpdateForm: Decodable {
        let isAdmin: String?
        let isEditor: String?
        let isModerator: String?
        let isReader: String?
        let canRead: String?
        let canWrite: String?
        let canDelete: String?
    }

    func updateUserRoles(request: Request, context: Context) async throws -> Response {
        let currentUser = try context.requireIdentity()
        guard currentUser.roles.contains(.admin) else { throw HTTPError(.forbidden) }
        let targetId = try context.parameters.require("id", as: UUID.self)
        guard let target = try await User.find(targetId, on: fluent.db()) else {
            throw HTTPError(.notFound)
        }
        let form = try await request.decode(as: RoleUpdateForm.self, context: context)
        var roles = Role()
        if form.isAdmin != nil { roles.insert(.admin) }
        if form.isEditor != nil { roles.insert(.editor) }
        if form.isModerator != nil { roles.insert(.moderator) }
        if form.isReader != nil { roles.insert(.reader) }
        var perms = Permission()
        if form.canRead != nil { perms.insert(.postsRead) }
        if form.canWrite != nil { perms.insert(.postsWrite) }
        if form.canDelete != nil { perms.insert(.postsDelete) }
        target.rolesMask = roles.rawValue
        target.permissionsMask = perms.rawValue
        try await target.save(on: fluent.db())
        return .redirect(to: "/admin", type: .found)
    }

    // MARK: - Helpers

    private func roleNames(_ roles: Role) -> String {
        var names: [String] = []
        if roles.contains(.admin) { names.append("Admin") }
        if roles.contains(.editor) { names.append("Editor") }
        if roles.contains(.moderator) { names.append("Moderator") }
        if roles.contains(.reader) { names.append("Reader") }
        return names.isEmpty ? "None" : names.joined(separator: ", ")
    }

    private func permissionNames(_ perms: Permission) -> String {
        var names: [String] = []
        if perms.contains(.postsRead) { names.append("Read") }
        if perms.contains(.postsWrite) { names.append("Write") }
        if perms.contains(.postsDelete) { names.append("Delete") }
        return names.isEmpty ? "None" : names.joined(separator: ", ")
    }
}
