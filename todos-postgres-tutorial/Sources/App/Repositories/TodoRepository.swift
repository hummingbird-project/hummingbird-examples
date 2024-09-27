import Foundation

/// Interface for storing and editing todos
protocol TodoRepository: Sendable {
    /// Create todo.
    func create(title: String, order: Int?, urlPrefix: String) async throws -> Todo
    /// Get todo
    func get(id: UUID) async throws -> Todo?
    /// List all todos
    func list() async throws -> [Todo]
    /// Update todo. Returns updated todo if successful
    func update(id: UUID, title: String?, order: Int?, completed: Bool?) async throws -> Todo?
    /// Delete todo. Returns true if successful
    func delete(id: UUID) async throws -> Bool
    /// Delete all todos
    func deleteAll() async throws
}
