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

        // The long introduction is the default: "LET'S GO" opens it ("Skip intro" ends it).
        step("onboarding-1-hook", tap: "LET\u{2019}S GO")
        step("onboarding-2-guess", tap: "SEE MY ACTUAL TIME", pre: { app.buttons["5\u{2013}6 hours"].tap() })
        // In UI tests this button skips the Screen Time box; there is no access, so no reveal slide.
        step("onboarding-3-check", tap: "OK, SHOW ME")
        step("onboarding-5-brain", tap: "CONTINUE")
        step("onboarding-6-slide", tap: "NEXT", pre: { app.buttons["onboarding-slide-knob"].tap() })
        step("onboarding-7-apps-wait", tap: "NEXT")
        step("onboarding-8-come-back", tap: "NEXT")
        step("onboarding-9-pulls", tap: "NEXT", pre: { app.buttons["Social"].tap() })
        // Back returns to the previous slide with the choice kept.
        XCTAssertTrue(app.buttons["Skip for now"].waitForExistence(timeout: 10))
        app.buttons["Back"].tap()
        XCTAssertTrue(app.buttons["NEXT"].waitForExistence(timeout: 5))
        app.buttons["NEXT"].tap()
        step("onboarding-10-lock", tap: "Skip for now")
        step("onboarding-11-goals", tap: "NEXT", pre: { app.buttons["Studying"].tap() })
        // The plan receipt is built from the answers; the Plus offer comes last ("Not now" ends the
        // introduction). The coach takes over on the real Focus screen.
        step("onboarding-12-plan", tap: "THIS IS MY PLAN")
        step("onboarding-13-plus", tap: "Not now")
        XCTAssertTrue(app.buttons["skip-focus-coach"].waitForExistence(timeout: 25))
        runCoachToSession(app)
    }

    /// The short way: "Skip intro" on the first slide goes straight to the coach.
    func testStartNowSkipsTheLongIntroduction() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing-calm-background", "-ui-testing-reset-state", "-ui-testing-onboarding"]
        app.launch()
        let start = app.buttons["Skip intro"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        sleep(2)
        capture("quick-1-hook")
        start.tap()
        XCTAssertTrue(app.buttons["skip-focus-coach"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["TAKE A GUESS"].exists)
        runCoachToSession(app)
    }

    /// The coach points at the real controls: task, minutes, apps (skipped here, the simulator has
    /// no Screen Time), then ONE hold. The first-win badge must not appear when the session starts.
    private func runCoachToSession(_ app: XCUIApplication) {
        app.buttons["work-task"].tap()
        XCTAssertTrue(app.buttons["Studying"].waitForExistence(timeout: 5))
        app.buttons["Studying"].tap()
        capture("coach-task-win")
        XCTAssertTrue(app.buttons["25 minutes"].waitForExistence(timeout: 5))
        app.buttons["25 minutes"].tap()
        let skipApps = app.buttons["coach-skip-apps"]
        XCTAssertTrue(skipApps.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["coach-choose-apps"].exists)
        capture("coach-apps")
        skipApps.tap()
        passGoalAndFriend(app)
        let start = app.buttons["coach-hold-to-start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        capture("coach-hold")
        start.press(forDuration: 2)
        XCTAssertTrue(app.buttons["END SESSION"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["first-lock-in-stamp"].exists, "the badge belongs to a finished session")
        capture("coach-session-running")
        app.buttons["END SESSION"].tap()
        XCTAssertTrue(app.buttons["LOCK IN"].waitForExistence(timeout: 5))
    }

    /// The hands-on steps after the apps: one tap sets the real weekly goal, then the friend step
    /// (skipped here; adding one needs a second phone). There are no Next-only cards. The simulator
    /// sees no PC, so the PC step is left out.
    private func passGoalAndFriend(_ app: XCUIApplication) {
        let goal = app.buttons["coach-goal-4"]
        XCTAssertTrue(goal.waitForExistence(timeout: 5))
        capture("coach-goal")
        goal.tap()
        let later = app.buttons["coach-skip-friend"]
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["coach-add-friend"].exists)
        capture("coach-friend")
        later.tap()
        XCTAssertFalse(app.buttons["coach-next"].exists, "no talk-only cards")
    }

    /// Ending early is one calm choice: the time focused still counts, nothing to type or wait out.
    func testEndingEarlyIsNeutral() {
        let app = makeApp()
        app.launchArguments.append("-ui-testing-quit-sheet")
        app.launch()
        app.buttons["LOCK IN"].tap()
        XCTAssertTrue(app.buttons["END SESSION"].waitForExistence(timeout: 5))
        app.buttons["END SESSION"].tap()
        XCTAssertTrue(app.staticTexts["quit-focused-line"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields.count, 0, "nothing to type")
        XCTAssertFalse(app.staticTexts["Say it."].exists)
        capture("quit-neutral")
        // Keep going returns to the running session.
        app.buttons["quit-keep-going"].tap()
        XCTAssertTrue(app.buttons["END SESSION"].waitForExistence(timeout: 5))
        app.buttons["END SESSION"].tap()
        XCTAssertTrue(app.buttons["quit-end-session"].waitForExistence(timeout: 5))
        app.buttons["quit-end-session"].tap()
        XCTAssertTrue(app.buttons["LOCK IN"].waitForExistence(timeout: 5))
    }

    /// A finished session shows the time focused and offers to keep the same task.
    func testCompletionShowsTimeFocusedAndKeepsTheTask() {
        let app = makeApp()
        app.launchArguments += ["-ui-testing-short-session", "-ui-testing-completion-card"]
        app.launch()
        app.buttons["work-task"].tap()
        XCTAssertTrue(app.buttons["Studying"].waitForExistence(timeout: 5))
        app.buttons["Studying"].tap()
        app.buttons["Done"].tap()
        app.buttons["LOCK IN"].tap()
        XCTAssertTrue(app.buttons["END SESSION"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["completion-card"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.staticTexts["completion-minutes"].exists)
        XCTAssertTrue(app.staticTexts["first-lock-in-stamp"].exists, "the first finished session earns the badge")
        capture("completion-card")
        app.buttons["completion-keep"].tap()
        XCTAssertTrue(app.buttons["LOCK IN"].waitForExistence(timeout: 5))
        // The task is still picked for next time.
        XCTAssertTrue(app.buttons["work-task"].label.contains("Studying"))
    }

    func testCoachReduceMotionAndInterruptedHold() {
        let app = makeApp()
        app.launchArguments += ["-ui-testing-coach", "-ui-testing-reduce-motion"]
        app.launch()
        XCTAssertTrue(app.buttons["skip-focus-coach"].waitForExistence(timeout: 10))
        app.buttons["work-task"].tap()
        app.buttons["Studying"].tap()
        app.buttons["25 minutes"].tap()
        XCTAssertTrue(app.buttons["coach-skip-apps"].waitForExistence(timeout: 5))
        app.buttons["coach-skip-apps"].tap()
        passGoalAndFriend(app)
        let hold = app.buttons["coach-hold-to-start"]
        XCTAssertTrue(hold.waitForExistence(timeout: 5))
        capture("coach-reduce-motion")

        app.terminate()
        app.launchArguments.removeAll { $0 == "-ui-testing-reset-state" || $0 == "-ui-testing-coach" }
        app.launch()
        XCTAssertTrue(app.buttons["skip-focus-coach"].waitForExistence(timeout: 10))
        app.buttons["skip-focus-coach"].tap()
        XCTAssertTrue(app.buttons["LOCK IN"].isEnabled)
    }

    /// Real report: after picking 25 minutes the first time, tapping LOCK IN did nothing.
    func testLockInTapWorksWhileTheCoachShowsTheAppsStep() {
        let app = makeApp()
        app.launchArguments += ["-ui-testing-coach"]
        app.launch()
        app.buttons["work-task"].tap()
        XCTAssertTrue(app.buttons["Studying"].waitForExistence(timeout: 5))
        app.buttons["Studying"].tap()
        app.buttons["25 minutes"].tap()
        XCTAssertTrue(app.buttons["coach-skip-apps"].waitForExistence(timeout: 5))
        app.buttons["LOCK IN"].tap()
        XCTAssertTrue(app.buttons["END SESSION"].waitForExistence(timeout: 5))
    }

    /// Skipping everything reaches the main screen with no session, and leaves out the year slide.
    func testFirstRunCanBeSkipped() {
        let app = XCUIApplication()
        app.launchArguments += ["-ui-testing-calm-background", "-ui-testing-reset-state", "-ui-testing-onboarding"]
        app.launch()

        func tap(_ label: String) {
            let button = app.buttons[label]
            XCTAssertTrue(button.waitForExistence(timeout: 10), "missing \(label)")
            button.tap()
        }
        tap("LET\u{2019}S GO")
        tap("Skip")                      // guess
        tap("Not now")                   // Screen Time (no guess, so the hours slide is left out)
        tap("onboarding-slide-knob")     // one slide, you're in (NEXT unlocks after the slide)
        tap("NEXT")
        tap("NEXT")                      // swipe later (notifications go to Later)
        tap("NEXT")                      // stack up the days (the week stacks up)
        tap("Skip")                      // what pulls you in
        tap("Skip for now")              // lock apps
        XCTAssertFalse(app.buttons["LET\u{2019}S DO IT"].exists)
        tap("Skip")                      // goals
        tap("THIS IS MY PLAN")           // the plan receipt
        tap("Not now")                   // the Plus offer
        // The plan prints, then the introduction ends by itself and the coach starts.
        XCTAssertTrue(app.buttons["skip-focus-coach"].waitForExistence(timeout: 25))
        app.buttons["skip-focus-coach"].tap()
        XCTAssertTrue(app.buttons["LOCK IN"].waitForExistence(timeout: 10))
    }

    /// The test button on the main screen replays the first-run slides.
    func testReplayIntroButtonShowsTheSlidesAgain() {
        let app = makeApp()
        app.launch()
        let menu = app.buttons["test-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        menu.tap()
        let replay = app.buttons["Replay intro"]
        XCTAssertTrue(replay.waitForExistence(timeout: 5))
        replay.tap()
        XCTAssertTrue(app.buttons["LET\u{2019}S GO"].waitForExistence(timeout: 10))
    }
}
