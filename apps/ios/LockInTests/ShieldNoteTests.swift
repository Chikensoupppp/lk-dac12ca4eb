import XCTest
@testable import LockIn

/// The words on SwipeLater's block screen, and the end time the shield extensions read.
final class ShieldNoteTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "ShieldNoteTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testCurrentIsNilWhenNothingSavedOrAlreadyOver() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertNil(ShieldNote.current(now: now, defaults: defaults))
        ShieldNote.save(endsAt: now.addingTimeInterval(-1), locked: false, defaults: defaults)
        XCTAssertNil(ShieldNote.current(now: now, defaults: defaults))
        ShieldNote.save(endsAt: now.addingTimeInterval(600), locked: true, defaults: defaults)
        XCTAssertEqual(ShieldNote.current(now: now, defaults: defaults),
                       ShieldNote.Now(endsAt: now.addingTimeInterval(600), locked: true))
        ShieldNote.clear(defaults: defaults)
        XCTAssertNil(ShieldNote.current(now: now, defaults: defaults))
    }

    func testTitleUsesTheAppNameOrLockedTime() {
        let end = Date(timeIntervalSince1970: 2_000_000)
        XCTAssertEqual(ShieldNote.title(appName: "Instagram", session: .init(endsAt: end, locked: false)), "Instagram can wait.")
        XCTAssertEqual(ShieldNote.title(appName: "  ", session: nil), "This can wait.")
        XCTAssertEqual(ShieldNote.title(appName: nil, session: nil), "This can wait.")
        XCTAssertEqual(ShieldNote.title(appName: "Instagram", session: .init(endsAt: end, locked: true),
                                        timeStyle: { _ in "4:25 PM" }), "Locked till 4:25 PM.")
    }

    func testSubtitleSaysTimeLeft() {
        let now = Date(timeIntervalSince1970: 3_000_000)
        let open = ShieldNote.Now(endsAt: now.addingTimeInterval(18 * 60 - 20), locked: false)
        XCTAssertEqual(ShieldNote.subtitle(session: open, now: now), "You\u{2019}re locked in. 18 min left.\nIt\u{2019}ll still be here after.")
        XCTAssertEqual(ShieldNote.subtitle(session: nil, now: now), "You\u{2019}re locked in.\nIt\u{2019}ll still be here after.")
        XCTAssertEqual(ShieldNote.subtitle(session: .init(endsAt: now.addingTimeInterval(60), locked: true), now: now),
                       "No way out this time.\nThat was the deal.")
    }

    func testLeft() {
        XCTAssertEqual(ShieldNote.left(30), "Less than a minute left")
        XCTAssertEqual(ShieldNote.left(60), "1 min left")
        XCTAssertEqual(ShieldNote.left(61), "2 min left")
        XCTAssertEqual(ShieldNote.left(3600), "1 h left")
        XCTAssertEqual(ShieldNote.left(3900), "1 h 5 min left")
    }
}
