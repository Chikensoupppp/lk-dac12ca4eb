import XCTest
@testable import LockIn

final class OnboardingMathTests: XCTestCase {
    func testDaysPerYearMatchesPlainArithmetic() {
        // 5.5 hours a day * 365 days / 24 hours = 83.65 full days.
        XCTAssertEqual(OnboardingMath.daysPerYear(hoursIndex: 2), 84)
        // 1.5 hours a day = 22.8 days.
        XCTAssertEqual(OnboardingMath.daysPerYear(hoursIndex: 0), 23)
    }

    func testHalfIsHalfOfTheTotal() {
        XCTAssertEqual(OnboardingMath.daysBackIfHalved(hoursIndex: 2), 42)
    }

    func testUnknownChoiceGivesZero() {
        XCTAssertEqual(OnboardingMath.daysPerYear(hoursIndex: 9), 0)
        XCTAssertEqual(OnboardingMath.daysPerYear(hoursIndex: -1), 0)
    }

    func testDoneFlagRoundTrips() {
        let suite = UserDefaults(suiteName: "onboarding-test-\(UUID().uuidString)")!
        XCTAssertFalse(suite.bool(forKey: OnboardingStore.doneKey))
        OnboardingStore.save(hoursIndex: 1, categories: ["Social"], goals: ["Study", "Work"], defaults: suite)
        XCTAssertTrue(suite.bool(forKey: OnboardingStore.doneKey))
        XCTAssertEqual(suite.integer(forKey: OnboardingStore.hoursKey), 1)
        XCTAssertEqual(suite.stringArray(forKey: OnboardingStore.goalsKey), ["Study", "Work"])
    }
}
