import RevenueCat
import StoreKit
import UserNotifications

/// Lock In Plus through Apple's In-App Purchase (StoreKit 2). One yearly subscription.
///
/// RevenueCat runs alongside in "purchases completed by my app" mode: the app still buys with
/// StoreKit 2 (so nothing here depends on RevenueCat being up), and RevenueCat records each
/// purchase for the dashboard, charts and, later, Plus on the PC. Without a key it stays off.
///
/// The product must exist in App Store Connect with this exact ID, in a subscription group, with
/// a free-trial introductory offer. Until it does, `loadState` is `.unavailable` and the offer
/// slide says so instead of showing a price. Prices always come from the App Store, never from code.
@MainActor
final class PlusStore: ObservableObject {
    static let yearlyID = "com.brandon132199.lockin.plus.yearly"
    static let monthlyID = "com.brandon132199.lockin.plus.monthly"
    static let allIDs: Set<String> = [yearlyID, monthlyID]

    enum LoadState: Equatable { case loading, ready, unavailable }

    @Published private(set) var loadState: LoadState = .loading
    /// Both plans, as the App Store returned them.
    @Published private(set) var products: [Product] = []
    /// The plan the offer screen has picked. Yearly by default (it has the free trial).
    @Published var selectedID = PlusStore.yearlyID
    /// The picked plan, or whichever one loaded.
    var product: Product? { products.first { $0.id == selectedID } ?? products.first }
    var yearly: Product? { products.first { $0.id == Self.yearlyID } }
    var monthly: Product? { products.first { $0.id == Self.monthlyID } }
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

    /// This phone's RevenueCat user id, sent to the PC so it can check Plus for itself. Nil when off.
    static var revenueCatUserID: String? { Purchases.isConfigured ? Purchases.shared.appUserID : nil }

    /// Turns RevenueCat on when the build has a public key (see project.yml, REVENUECAT_API_KEY).
    static func configureRevenueCat() {
        guard !Purchases.isConfigured,
              let key = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String,
              key.hasPrefix("appl_") else { return }
        #if DEBUG
        Purchases.logLevel = .warn
        #endif
        Purchases.configure(with: Configuration.Builder(withAPIKey: key)
            .with(purchasesAreCompletedBy: .myApp, storeKitVersion: .storeKit2)
            .build())
    }

    /// True for TestFlight AND for App Review: both run with a sandbox receipt. Used only to
    /// reset first-run state between test builds (FreshStart). It must never unlock Plus: App
    /// Review would then never see the paywall or be able to test the purchase (Guideline 2.1).
    /// Testers get Plus the real way, with a free sandbox purchase.
    static let isTestFlight = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"

    var hasPlus: Bool { isPlus }

    func load() async {
        do {
            products = try await Product.products(for: Self.allIDs)
                .sorted { $0.id == Self.yearlyID && $1.id != Self.yearlyID }
            if yearly == nil, let first = products.first { selectedID = first.id }
            if let subscription = products.first?.subscription {
                // Both plans share one subscription group, so eligibility is the same for both.
                trialEligible = await subscription.isEligibleForIntroOffer
            }
            loadState = products.isEmpty ? .unavailable : .ready
        } catch {
            loadState = .unavailable
        }
    }

    func refreshEntitlement() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, Self.allIDs.contains(t.productID), t.revocationDate == nil {
                active = true
            }
        }
        isPlus = active
    }

    /// The free-trial length in days, when the product has one and the user can still get it.
    var trialDays: Int? { trialDays(for: product) }

    /// The same, for one plan (the yearly chip shows its trial even while monthly is picked).
    func trialDays(for product: Product?) -> Int? {
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
            let result = try await product.purchase()
            if Purchases.isConfigured { _ = try? await Purchases.shared.recordPurchase(result) }
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    message = "The App Store could not confirm the purchase."
                    return false
                }
                await transaction.finish()
                await refreshEntitlement()
                await scheduleTrialReminder(for: transaction)
                Analytics.track("plus_purchased", ["product": product.id])
                Analytics.set(["has_plus": true])
                return true
            case .userCancelled, .pending:
                Analytics.track("plus_purchase_cancelled", ["product": product.id])
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
            if Purchases.isConfigured { _ = try? await Purchases.shared.syncPurchases() }
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
