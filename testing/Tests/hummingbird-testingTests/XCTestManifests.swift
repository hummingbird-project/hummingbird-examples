import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(hummingbird_testingTests.allTests),
    ]
}
#endif
