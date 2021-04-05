# hummingbird-testing

### Proper testing is essential for production-ready code.

This is a working class example of using `XCTest` for hummingbird applications.


## How to Write a Testable App

Some notable differences in this technique.

1. The Package creates a Library for the App (`Sources/hummingbird-testing`) and an executable (`Sources/Run`). This is because XCTest can’t distinguish between a Swift Package `main.swift` file and its own main used for testing.
2. The App uses a `Boot` object to configure and run the app. This allows us to reuse the `Boot.configureRoutes(_:)` method on the `HBApplication(testing: .embedded)` object. Embedded testing should not be in production code.
3. Write XCTestCase as usual inside the Tests folder.

## How to Use

### From the Terminal. 
- Test with `swift test`
- Run the app with `swift run Run --hostname localhost --port 8888

### From Xcode
- (Optional) Modify hostname and port by using `Product > Scheme > Edit Scheme… (Command <)` and modifying the properties in the Arguments tab. Be sure to note the Run vs Test options in the sidebar. 
- Test with `Proudct > Test (Command U)`
- Run the app with  `Product > Run (Command R)`
