import FluentKit
import Foundation
import Hummingbird
import HummingbirdBcrypt
import HummingbirdFluent
import Mustache
import NIOPosix

/// Serves the browser-facing HTML pages for the ABAC document management demo.
struct WebController {
    typealias Context = AppRequestContext

    let fluent: Fluent
    let mustacheLibrary: MustacheLibrary
    let documentsTemplate: MustacheTemplate
    let documentTemplate: MustacheTemplate
    let loginTemplate: MustacheTemplate
    let signupTemplate: MustacheTemplate
    let errorTemplate: MustacheTemplate

    init(mustacheLibrary: MustacheLibrary, fluent: Fluent) {
        self.mustacheLibrary = mustacheLibrary
        self.fluent = fluent
        guard
            let documentsTemplate = mustacheLibrary.getTemplate(named: "documents"),
            let documentTemplate = mustacheLibrary.getTemplate(named: "document"),
            let loginTemplate = mustacheLibrary.getTemplate(named: "login"),
            let signupTemplate = mustacheLibrary.getTemplate(named: "signup"),
            let errorTemplate = mustacheLibrary.getTemplate(named: "error")
        else {
            preconditionFailure("Failed to load mustache templates from bundle")
        }
        self.documentsTemplate = documentsTemplate
        self.documentTemplate = documentTemplate
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
            // Authenticated web routes
            .add(middleware: WebSessionMiddleware(fluent: fluent))
            .add(middleware: WebRedirectMiddleware(to: "/login"))
            .get("/", use: home)
            .post("/web/documents", use: createDocument)
            .get("/view/:id", use: viewDocument)
            .post("/web/documents/:id/update", use: updateDocument)
    }

    // MARK: - Auth

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
        let department: String
        let clearanceLevel: Int
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
        let user = User(
            name: details.name,
            passwordHash: hash,
            department: details.department,
            clearanceLevel: min(max(details.clearanceLevel, 0), 3),
            permissionsList: "documents:create,documents:read,documents:write"
        )
        try await user.save(on: db)
        return .redirect(to: "/login", type: .found)
    }

    func logout(request: Request, context: Context) async throws -> Response {
        context.sessions.clearSession()
        return .redirect(to: "/login", type: .found)
    }

    // MARK: - Home (document list)

    private func classificationLabel(_ c: Int) -> String {
        switch c {
        case 0: return "Public"
        case 1: return "Internal"
        case 2: return "Confidential"
        case 3: return "Restricted"
        default: return "Unknown"
        }
    }

    struct DocListItem {
        let id: String
        let title: String
        let department: String
        let classification: String
    }

    func home(request: Request, context: Context) async throws -> HTML {
        guard let user = context.currentUser else { throw HTTPError(.unauthorized) }
        let isAdmin = user.roles.contains(.admin)
        let allDocs: [Document]
        if isAdmin {
            allDocs = try await Document.query(on: fluent.db()).all()
        } else {
            let deptDocs = try await Document.query(on: fluent.db())
                .filter(\.$department == user.department)
                .all()
            allDocs = deptDocs.filter { $0.classification <= user.clearanceLevel }
        }
        let docItems = allDocs.map { doc in
            DocListItem(
                id: doc.id?.uuidString ?? "",
                title: doc.title,
                department: doc.department,
                classification: classificationLabel(doc.classification)
            )
        }
        let object: [String: Any] = [
            "name": user.name,
            "department": user.department,
            "clearanceLevel": user.clearanceLevel,
            "isAdmin": isAdmin,
            "documents": docItems,
        ]
        return HTML(html: documentsTemplate.render(object, library: mustacheLibrary))
    }

    // MARK: - Document CRUD

    struct CreateDocumentForm: Decodable {
        let title: String
        let content: String
        let classification: Int
    }

    func createDocument(request: Request, context: Context) async throws -> Response {
        guard let user = context.currentUser, let ownerId = user.id else {
            throw HTTPError(.unauthorized)
        }
        guard user.permissions.contains(.documentsCreate) else { throw HTTPError(.forbidden) }
        let form = try await request.decode(as: CreateDocumentForm.self, context: context)
        let doc = Document(
            title: form.title,
            content: form.content,
            department: user.department,
            classification: min(max(form.classification, 0), 3),
            ownerID: ownerId
        )
        try await doc.save(on: fluent.db())
        return .redirect(to: "/view/\(try doc.requireID().uuidString)", type: .found)
    }

    func viewDocument(request: Request, context: Context) async throws -> HTML {
        guard let user = context.currentUser else { throw HTTPError(.unauthorized) }
        let id = try context.parameters.require("id", as: UUID.self)
        guard let doc = try await Document.find(id, on: fluent.db()) else {
            throw HTTPError(.notFound)
        }
        let isAdmin = user.roles.contains(.admin)
        let sameDept = doc.department == user.department
        let sufficientClearance = user.clearanceLevel >= doc.classification
        let canRead = isAdmin || (sameDept && sufficientClearance)
        let needsClearance = !isAdmin && sameDept && !sufficientClearance
        let isOwner = doc.ownerID == user.id
        // If user has no department match at all and is not admin, deny access
        if !isAdmin && !sameDept {
            throw HTTPError(.forbidden)
        }
        let object: [String: Any] = [
            "name": user.name,
            "department": user.department,
            "clearanceLevel": user.clearanceLevel,
            "docId": doc.id?.uuidString ?? "",
            "docTitle": doc.title,
            "docContent": canRead ? doc.content : "",
            "docDepartment": doc.department,
            "docClassification": classificationLabel(doc.classification),
            "canRead": canRead,
            "needsClearance": needsClearance,
            "isOwner": isOwner,
        ]
        return HTML(html: documentTemplate.render(object, library: mustacheLibrary))
    }

    struct UpdateDocumentForm: Decodable {
        let title: String
        let content: String
    }

    func updateDocument(request: Request, context: Context) async throws -> Response {
        guard let user = context.currentUser else { throw HTTPError(.unauthorized) }
        let id = try context.parameters.require("id", as: UUID.self)
        guard let doc = try await Document.find(id, on: fluent.db()) else {
            throw HTTPError(.notFound)
        }
        let isAdmin = user.roles.contains(.admin)
        guard isAdmin || doc.ownerID == user.id else { throw HTTPError(.forbidden) }
        let form = try await request.decode(as: UpdateDocumentForm.self, context: context)
        doc.title = form.title
        doc.content = form.content
        try await doc.save(on: fluent.db())
        return .redirect(to: "/view/\(id.uuidString)", type: .found)
    }
}
