import XCTest

final class FocusUITests: XCTestCase {
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testStartAndEnd() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["45 minutes"].waitForExistence(timeout: 10))
        capture("idle-45")
        app.buttons["25 minutes"].tap()
        app.buttons["LOCK IN"].tap()
        XCTAssertTrue(app.buttons["END SESSION"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["Focus timer"].exists)
        capture("active")
        app.buttons["END SESSION"].tap()
        XCTAssertTrue(app.buttons["LOCK IN"].waitForExistence(timeout: 5))
    }

    func testNaturalCompletion() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing-short-session")
        app.launch()
        app.buttons["LOCK IN"].tap()
        XCTAssertTrue(app.buttons["END SESSION"].waitForExistence(timeout: 5))
        sleep(2)
        capture("partially-elapsed")
        XCTAssertTrue(app.buttons["LOCK IN"].waitForExistence(timeout: 15))
        capture("completed")
    }

    func testBackgroundAfterExpiry() {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing-short-session")
        app.launch()
        app.buttons["LOCK IN"].tap()
        XCTAssertTrue(app.buttons["END SESSION"].waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
        sleep(7)
        app.activate()
        XCTAssertTrue(app.buttons["LOCK IN"].waitForExistence(timeout: 10))
    }

    func testBackgroundBeforeExpiry() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["LOCK IN"].tap()
        XCTAssertTrue(app.buttons["END SESSION"].waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["END SESSION"].waitForExistence(timeout: 10))
        app.buttons["END SESSION"].tap()
    }

    func testLargeTextControlsAreReachable() {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["45 minutes"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["45 minutes"].isHittable)
        XCTAssertTrue(app.buttons["LOCK IN"].isHittable)
        capture("large-text")
    }
}
