import StoreKit
import UserNotifications

/// Lock In Plus through Apple's In-App Purchase (StoreKit 2). One yearly subscription.
///
/// The product must exist in App Store Connect with this exact ID, in a subscription group, with
/// a free-trial introductory offer. Until it does, `loadState` is `.unavailable` and the offer
/// slide says so instead of showing a price. Prices always come from the App Store, never from code.
@MainActor
final class PlusStore: ObservableObject {
    static let yearlyID = "com.brandon132199.lockin.plus.yearly"

    enum LoadState: Equatable { case loading, ready, unavailable }

    @Published private(set) var loadState: LoadState = .loading
    @Published private(set) var product: Product?
    @Published private(set) var isPlus = false
    @Published private(set) var trialEligible = false
    @Published private(set) var busy = false
    @Published var message: String?

    private var updates: Task<Void, Never>?

    init() {
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await self?.refreshEntitlement()
            }
        }
        Task { [weak self] in
            await self?.load()
            await self?.refreshEntitlement()
        }
    }

    deinit { updates?.cancel() }

    func load() async {
        do {
            let products = try await Product.products(for: [Self.yearlyID])
            product = products.first
            if let subscription = product?.subscription {
                trialEligible = await subscription.isEligibleForIntroOffer
            }
            loadState = product == nil ? .unavailable : .ready
        } catch {
            loadState = .unavailable
        }
    }

    func refreshEntitlement() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.yearlyID, t.revocationDate == nil {
                active = true
            }
        }
        isPlus = active
    }

    /// The free-trial length in days, when the product has one and the user can still get it.
    var trialDays: Int? {
        guard trialEligible, let offer = product?.subscription?.introductoryOffer,
              offer.paymentMode == .freeTrial else { return nil }
        let p = offer.period
        switch p.unit {
        case .day: return p.value
        case .week: return p.value * 7
        case .month: return p.value * 30
        case .year: return p.value * 365
        @unknown default: return nil
        }
    }

    /// "$29.99 a year", from the App Store.
    var priceLine: String? {
        guard let product else { return nil }
        let unit = product.subscription?.subscriptionPeriod.unit
        let per: String
        switch unit {
        case .year: per = "a year"
        case .month: per = "a month"
        case .week: per = "a week"
        default: per = ""
        }
        return "\(product.displayPrice) \(per)".trimmingCharacters(in: .whitespaces)
    }

    /// True when the purchase went through.
    func purchase() async -> Bool {
        guard let product, !busy else { return false }
        busy = true
        defer { busy = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    message = "The App Store could not confirm the purchase."
                    return false
                }
                await transaction.finish()
                await refreshEntitlement()
                await scheduleTrialReminder(for: transaction)
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            message = error.localizedDescription
            return false
        }
    }

    func restore() async {
        busy = true
        defer { busy = false }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            message = isPlus ? "Plus is back." : "No Plus purchase found for this Apple ID."
        } catch {
            message = error.localizedDescription
        }
    }

    /// The offer promises "Day 5: we remind you". This keeps that promise with a local
    /// notification two days before a free trial ends. Without notification permission there is
    /// no reminder, and the offer slide words the timeline to match (see `PlusOfferStep`).
    private func scheduleTrialReminder(for transaction: Transaction) async {
        guard transaction.offerType == .introductory, let ends = transaction.expirationDate else { return }
        let fireAt = ends.addingTimeInterval(-2 * 24 * 3600)
        guard fireAt > .now else { return }
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        guard granted else { return }
        let content = UNMutableNotificationContent()
        content.title = "Your free trial ends in 2 days"
        content.body = "Keep Plus, or cancel any time in Settings > Apple ID > Subscriptions."
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireAt)
        let request = UNNotificationRequest(identifier: "lockin.plus.trial-reminder", content: content,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false))
        try? await center.add(request)
    }
}
