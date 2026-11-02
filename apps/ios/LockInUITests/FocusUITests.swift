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
        XCTAssertTrue(app.buttons["25 minutes"].isSelected)
        app.buttons["LOCK IN"].tap()
        XCTAssertTrue(app.buttons["END SESSION"].waitForExistence(timeout: 5))
        let timer = app.otherElements["Focus timer"]
        XCTAssertTrue(timer.exists)
        let initialValue = timer.value as? String
        XCTAssertNotNil(initialValue)
        sleep(3)
        XCTAssertNotEqual(timer.value as? String, initialValue)
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
        app.launchArguments += ["-ui-testing-short-session", "-ui-testing-completion-count"]
        app.launch()
        app.buttons["LOCK IN"].tap()
        XCTAssertTrue(app.buttons["END SESSION"].waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
        sleep(7)
        app.activate()
        XCTAssertTrue(app.buttons["LOCK IN"].waitForExistence(timeout: 10))
        let count = app.staticTexts["completion-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        XCTAssertEqual(count.label, "Completion count: 1")
        sleep(2)
        XCTAssertEqual(count.label, "Completion count: 1")
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
        for minutes in [15, 25, 45, 60, 90] {
            XCTAssertTrue(app.buttons["\(minutes) minutes"].isHittable, "\(minutes) minute control should be reachable")
        }
        XCTAssertTrue(app.buttons["LOCK IN"].isHittable)
        capture("large-text")
    }

    func testReduceMotionTimerAccessibility() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing-reduce-motion", "-ui-testing-short-session"]
        app.launch()
        let timer = app.otherElements["Focus timer"]
        XCTAssertTrue(timer.waitForExistence(timeout: 10))
        app.buttons["LOCK IN"].tap()
        XCTAssertTrue(app.buttons["END SESSION"].waitForExistence(timeout: 5))
        XCTAssertTrue((timer.value as? String ?? "").contains("remaining"))
        capture("reduce-motion-active")
        XCTAssertTrue(app.buttons["LOCK IN"].waitForExistence(timeout: 15))
    }
}
