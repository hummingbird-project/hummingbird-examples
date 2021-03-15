import Hummingbird
import HummingbirdMustache

extension HBApplication {
    var mustache: HBMustacheLibrary {
        get { self.extensions.get(\.mustache) }
        set { self.extensions.set(\.mustache, value: newValue)}
    }
}

extension HBRequest {
    var mustache: HBMustacheLibrary { self.application.mustache }
}
