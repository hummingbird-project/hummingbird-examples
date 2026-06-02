import FluentKit
import Mustache

extension FieldProperty {
    public func transform(_ name: String) -> Any? {
        switch name {
        case "wrappedValue":
            return wrappedValue
        default:
            return nil
        }
    }
}

extension IDProperty {
    public func transform(_ name: String) -> Any? {
        switch name {
        case "wrappedValue":
            return wrappedValue
        default:
            return nil
        }
    }
}

#if hasFeature(RetroactiveAttribute)
extension FieldProperty: @retroactive MustacheTransformable {}
extension IDProperty: @retroactive MustacheTransformable {}
#else
extension FieldProperty: MustacheTransformable {}
extension IDProperty: MustacheTransformable {}
#endif
