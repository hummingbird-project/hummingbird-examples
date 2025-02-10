import Hummingbird

extension Environment {
    public struct RequireError: Error {
        let message: String
    }
    public func require(_ s: String) throws -> String {
        guard let variable = self.get(s) else {
            throw RequireError(message: "Expected environment variable '\(s)' does not exist")
        }
        return variable
    }

    public func require<T: LosslessStringConvertible>(_ s: String, as: T.Type) throws -> T {
        let variable = try require(s)
        guard let result = T(variable)
        else {
            throw RequireError(message: "Environment variable '\(s)' can not be converted to the expected type (\(T.self))")
        }
        return result
    }
}