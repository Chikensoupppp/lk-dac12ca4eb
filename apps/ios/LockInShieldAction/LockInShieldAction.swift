import ManagedSettings
import UserNotifications

/// The buttons on SwipeLater's block screen (`LockInShield`). "Back to focus" closes the blocked
/// app. "Swipe it later" also closes it, and leaves a reminder for when the session ends, so the
/// thing they wanted is not lost. Without notification permission it just closes.
final class LockInShieldAction: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        respond(action, completionHandler)
    }

    private func respond(_ action: ShieldAction, _ done: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .secondaryButtonPressed:
            remindAtEnd { done(.close) }
        default:
            done(.close)
        }
    }

    private func remindAtEnd(then: @escaping () -> Void) {
        guard let session = ShieldNote.current(), !session.locked else { then(); return }
        let content = UNMutableNotificationContent()
        content.title = "Session done. Your apps are back."
        content.body = "Whatever you swiped later is waiting."
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, session.endsAt.timeIntervalSinceNow), repeats: false)
        // Same id every time: tapping it twice keeps one reminder.
        let request = UNNotificationRequest(identifier: ShieldNote.reminderID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { _ in then() }
    }
}
