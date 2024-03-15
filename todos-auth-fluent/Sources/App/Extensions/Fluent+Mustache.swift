import FluentKit
import Mustache

/// Extend @propertyWrapper FieldProperty to enable mustache transform functions and add one
/// to access the wrappedValue. In the mustache template you would access this with
/// `{{wrappedValue(_myProperty)}}`. Note the `_` prefix on the property name. This is
/// required as this is how property wrappers appear in the Mirror reflection data.
extension FieldProperty: MustacheTransformable {
    public func transform(_ name: String) -> Any? {
        switch name {
        case "wrappedValue":
            return wrappedValue
        default:
            return nil
        }
    }
}

/// Extend @propertyWrapper IDProperty to enable mustache transform functions and add one
/// to access the wrappedValue. In the mustache template you would access this with
/// `{{wrappedValue(_myID)}}`. Note the `_` prefix on the property name. This is
/// required as this is how property wrappers appear in the Mirror reflection data.
extension IDProperty: MustacheTransformable {
    public func transform(_ name: String) -> Any? {
        switch name {
        case "wrappedValue":
            return wrappedValue
        default:
            return nil
        }
    }
}
