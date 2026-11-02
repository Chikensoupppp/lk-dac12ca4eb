import XCTest

final class FocusUITests: XCTestCase {
    func testStartAndEnd() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["45 minutes"].waitForExistence(timeout: 10))
        app.buttons["25 minutes"].tap()
        app.buttons["LOCK IN"].tap()
        XCTAssertTrue(app.buttons["END SESSION"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["Focus timer"].exists)
        app.buttons["END SESSION"].tap()
        XCTAssertTrue(app.buttons["LOCK IN"].waitForExistence(timeout: 5))
    }

    func testNaturalCompletion() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing-short-session")
        app.launch()
        app.buttons["LOCK IN"].tap()
        XCTAssertTrue(app.buttons["END SESSION"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["LOCK IN"].waitForExistence(timeout: 15))
    }
}
