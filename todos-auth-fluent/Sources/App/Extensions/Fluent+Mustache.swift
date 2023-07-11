import FluentKit
import HummingbirdMustache

// Extend @propertyWrapper Field so it will render its contents. Property wrappers
// have a '_' prefix before them when you use Mirror reflection so you need to add
// this in your mustache template
extension FieldProperty: HBMustacheCustomRenderable {
    /// default version returning the standard rendering
    public var renderText: String {
        String(describing: self.wrappedValue)
    }

    /// default version returning false
    public var isNull: Bool {
        if let value = self.wrappedValue as? Bool {
            return !value
        }
        return self.value == nil
    }
}

extension IDProperty: HBMustacheCustomRenderable {
    /// default version returning the standard rendering
    public var renderText: String {
        self.wrappedValue.map { String(describing: $0) } ?? ""
    }

    /// default version returning false
    public var isNull: Bool {
        self.wrappedValue == nil
    }
}
