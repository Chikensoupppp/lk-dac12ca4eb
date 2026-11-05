import XCTest

final class FocusUITests: XCTestCase {
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Every test starts from a clean persisted state unless it relaunches on purpose.
    private func makeApp(reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-testing-calm-background")
        if reset { app.launchArguments.append("-ui-testing-reset-state") }
        return app
    }

    func testStartAndEnd() {
        let app = makeApp()
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
        let app = makeApp()
        app.launchArguments.append("-ui-testing-short-session")
        app.launch()
        app.buttons["LOCK IN"].tap()
        XCTAssertTrue(app.buttons["END SESSION"].waitForExistence(timeout: 5))
        sleep(2)
        capture("partially-elapsed")
        // Sample the end transition on the real simulator; capture overhead may
        // vary, so these frames are evidence rather than a timing benchmark.
        for frame in 0..<14 {
            capture("completion-frame-\(frame)")
            Thread.sleep(forTimeInterval: 0.25)
        }
        XCTAssertTrue(app.buttons["LOCK IN"].waitForExistence(timeout: 15))
        capture("completed")
    }

    func testBackgroundAfterExpiry() {
        let app = makeApp()
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
        let app = makeApp()
        app.launch()
        app.buttons["LOCK IN"].tap()
        XCTAssertTrue(app.buttons["END SESSION"].waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["END SESSION"].waitForExistence(timeout: 10))
        app.buttons["END SESSION"].tap()
    }

    func testLargeTextControlsAreReachable() {
        let app = makeApp()
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
        let app = makeApp()
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

    // MARK: Relaunch recovery

    func testActiveSessionSurvivesTermination() {
        let app = makeApp()
        app.launch()
        app.buttons["25 minutes"].tap()
        app.buttons["LOCK IN"].tap()
        XCTAssertTrue(app.buttons["END SESSION"].waitForExistence(timeout: 5))
        app.terminate()

        let relaunched = makeApp(reset: false)
        relaunched.launch()
        XCTAssertTrue(relaunched.buttons["END SESSION"].waitForExistence(timeout: 10))
        let timer = relaunched.otherElements["Focus timer"]
        XCTAssertTrue(timer.exists)
        XCTAssertTrue((timer.value as? String ?? "").contains("remaining"))
        capture("restored-active")
        relaunched.buttons["END SESSION"].tap()
        XCTAssertTrue(relaunched.buttons["LOCK IN"].waitForExistence(timeout: 5))
    }

    func testRelaunchAfterExpiryCompletesExactlyOnce() {
        let app = makeApp()
        app.launchArguments += ["-ui-testing-short-session"]
        app.launch()
        app.buttons["LOCK IN"].tap()
        XCTAssertTrue(app.buttons["END SESSION"].waitForExistence(timeout: 5))
        app.terminate()
        sleep(7)

        let relaunched = makeApp(reset: false)
        relaunched.launchArguments += ["-ui-testing-completion-count"]
        relaunched.launch()
        XCTAssertTrue(relaunched.buttons["LOCK IN"].waitForExistence(timeout: 10))
        XCTAssertFalse(relaunched.buttons["END SESSION"].exists)
        let count = relaunched.staticTexts["completion-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        XCTAssertEqual(count.label, "Completion count: 1")
        capture("restored-expired")
        relaunched.terminate()

        // The expired record was cleared, so another launch is plainly idle.
        let third = makeApp(reset: false)
        third.launchArguments += ["-ui-testing-completion-count"]
        third.launch()
        XCTAssertTrue(third.buttons["LOCK IN"].waitForExistence(timeout: 10))
        XCTAssertEqual(third.staticTexts["completion-count"].label, "Completion count: 0")
    }

    func testEarlyCancellationDoesNotRestore() {
        let app = makeApp()
        app.launch()
        app.buttons["LOCK IN"].tap()
        XCTAssertTrue(app.buttons["END SESSION"].waitForExistence(timeout: 5))
        app.buttons["END SESSION"].tap()
        XCTAssertTrue(app.buttons["LOCK IN"].waitForExistence(timeout: 5))
        app.terminate()

        let relaunched = makeApp(reset: false)
        relaunched.launch()
        XCTAssertTrue(relaunched.buttons["LOCK IN"].waitForExistence(timeout: 10))
        XCTAssertFalse(relaunched.buttons["END SESSION"].exists)
    }

    // MARK: Restrictions

    func testRestrictionsSheetReportsUnauthorizedStateHonestly() {
        let app = makeApp()
        app.launch()
        let open = app.buttons["Restrictions"]
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        capture("idle-with-restrictions-button")
        open.tap()
        let status = app.staticTexts["restrictions-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        // The simulator cannot grant Screen Time access; the sheet must not claim shields are on.
        XCTAssertFalse(status.label.contains("Shields are on"))
        capture("restrictions-sheet")
        app.buttons["Done"].tap()
        app.buttons["LOCK IN"].tap()
        XCTAssertTrue(app.buttons["END SESSION"].waitForExistence(timeout: 5))
        // No shields were applied, so no shield status line is shown.
        XCTAssertFalse(app.staticTexts["restrictions-line"].exists)
        XCTAssertFalse(app.buttons["Restrictions"].exists)
        app.buttons["END SESSION"].tap()
    }

    // MARK: First-run flow

    func testFirstRunFlowReachesAFocusSession() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing-calm-background", "-ui-testing-reset-state", "-ui-testing-onboarding"]
        app.launch()

        func step(_ name: String, tap label: String, pre: (() -> Void)? = nil) {
            let button = app.buttons[label]
            XCTAssertTrue(button.waitForExistence(timeout: 10), "missing \(label) on \(name)")
            sleep(2)
            capture(name)
            pre?()
            button.tap()
        }

        step("onboarding-1-hero", tap: "SHOW ME")
        step("onboarding-2-hours", tap: "NEXT", pre: { app.buttons["5 to 6 hours"].tap() })
        step("onboarding-3-categories", tap: "NEXT", pre: { app.buttons["Social"].tap() })
        step("onboarding-4-permission", tap: "CONTINUE")
        step("onboarding-5-shield", tap: "Skip for now")
        step("onboarding-6-goals", tap: "NEXT", pre: { app.buttons["Study"].tap() })
        step("onboarding-7-year", tap: "LET\u{2019}S DO IT")
        step("onboarding-8-pc", tap: "I only have a phone")
        step("onboarding-9-plus", tap: "NEXT")
        step("onboarding-10-ready", tap: "START 25 MINUTES")

        XCTAssertTrue(app.buttons["END SESSION"].waitForExistence(timeout: 10))
        app.buttons["END SESSION"].tap()
        XCTAssertTrue(app.buttons["LOCK IN"].waitForExistence(timeout: 5))
    }
}
