import Foundation
import RevenueCat

// MARK: - SubscriptionRevenueCatAdapting

/// The protocol that abstracts all RevenueCat SDK calls.
///
/// The library ships a concrete implementation — ``RevenueCatSubscriptionAdapter`` —
/// but you can supply your own conforming type for unit testing without touching
/// the real RevenueCat SDK.
///
/// ```swift
/// // Inject a mock adapter for testing
/// let manager = SubscriptionManager(adapter: MockRevenueCatAdapter())
/// ```
@MainActor
public protocol SubscriptionRevenueCatAdapting: AnyObject {
    /// Configures the RevenueCat SDK with the supplied kit configuration.
    func configure(with configuration: SubscriptionKitConfiguration) throws
    /// Returns the in-memory cached customer info without a network call, if available.
    func cachedCustomerInfo() -> SubscriptionCustomerSnapshot?
    /// Fetches fresh customer info from RevenueCat.
    func customerInfo() async throws -> SubscriptionCustomerSnapshot
    /// Fetches available packages for the specified offering or placement.
    func offerings(identifier: String?, placementIdentifier: String?) async throws -> [SubscriptionPackage]
    /// Returns an `AsyncStream` of customer info pushed by the RevenueCat SDK.
    func customerInfoUpdates() -> AsyncStream<SubscriptionCustomerSnapshot>
    /// Initiates a purchase for the given package.
    func purchase(package: SubscriptionPackage) async throws -> SubscriptionPurchaseOutcome
    /// Restores previously completed purchases.
    func restorePurchases() async throws -> SubscriptionCustomerSnapshot
    /// Logs in with an app-supplied user ID.
    func logIn(appUserID: String) async throws -> SubscriptionCustomerSnapshot
    /// Logs out the current RevenueCat user.
    func logOut() async throws -> SubscriptionCustomerSnapshot
    /// Returns the Apple subscription management URL for the current customer.
    func managementURL() async throws -> URL?
}

// MARK: - RevenueCatSubscriptionAdapter

/// The live RevenueCat SDK adapter used by default in ``SubscriptionManager``.
@MainActor
public final class RevenueCatSubscriptionAdapter: SubscriptionRevenueCatAdapting {
    private var isConfigured = false

    public init() {}

    public func configure(with configuration: SubscriptionKitConfiguration) throws {
        try configuration.validate()

        if configuration.debugLoggingEnabled {
            Purchases.logLevel = .debug
        }

        guard !isConfigured else { return }

        var builder = Configuration.Builder(withAPIKey: configuration.publicAPIKey)
        if let appUserID = configuration.appUserID {
            builder = builder.with(appUserID: appUserID)
        }
        Purchases.configure(with: builder.build())
        isConfigured = true
    }

    public func cachedCustomerInfo() -> SubscriptionCustomerSnapshot? {
        Purchases.shared.cachedCustomerInfo.map(SubscriptionCustomerSnapshot.init(customerInfo:))
    }

    public func customerInfo() async throws -> SubscriptionCustomerSnapshot {
        try await SubscriptionCustomerSnapshot(customerInfo: Purchases.shared.customerInfo())
    }

    public func offerings(identifier: String?, placementIdentifier: String?) async throws -> [SubscriptionPackage] {
        let offerings = try await Purchases.shared.offerings()

        let offering: Offering?
        if let identifier {
            offering = offerings.offering(identifier: identifier)
        } else if let placementIdentifier {
            offering = offerings.currentOffering(forPlacement: placementIdentifier)
        } else {
            offering = offerings.current
        }

        return offering?.availablePackages.map(SubscriptionPackage.init(package:)) ?? []
    }

    public func customerInfoUpdates() -> AsyncStream<SubscriptionCustomerSnapshot> {
        AsyncStream { continuation in
            let task = Task {
                for try await customerInfo in Purchases.shared.customerInfoStream {
                    continuation.yield(SubscriptionCustomerSnapshot(customerInfo: customerInfo))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    public func purchase(package: SubscriptionPackage) async throws -> SubscriptionPurchaseOutcome {
        guard let revenueCatPackage = package.revenueCatPackage as? Package else {
            throw SubscriptionManagerError.packageMissingRevenueCatBacking
        }

        let result = try await Purchases.shared.purchase(package: revenueCatPackage)
        if result.userCancelled {
            return .cancelled
        }
        return .success(SubscriptionCustomerSnapshot(customerInfo: result.customerInfo))
    }

    public func restorePurchases() async throws -> SubscriptionCustomerSnapshot {
        try await SubscriptionCustomerSnapshot(customerInfo: Purchases.shared.restorePurchases())
    }

    public func logIn(appUserID: String) async throws -> SubscriptionCustomerSnapshot {
        let result = try await Purchases.shared.logIn(appUserID)
        return SubscriptionCustomerSnapshot(customerInfo: result.customerInfo)
    }

    public func logOut() async throws -> SubscriptionCustomerSnapshot {
        try await SubscriptionCustomerSnapshot(customerInfo: Purchases.shared.logOut())
    }

    public func managementURL() async throws -> URL? {
        if let cachedURL = Purchases.shared.cachedCustomerInfo?.managementURL {
            return cachedURL
        }
        return try await Purchases.shared.customerInfo().managementURL
    }
}

// MARK: - Private Extensions

private extension SubscriptionCustomerSnapshot {
    init(customerInfo: CustomerInfo) {
        let activeIDs = Set(customerInfo.entitlements.active.keys)
        self.init(activeEntitlementIDs: activeIDs, managementURL: customerInfo.managementURL)
    }
}

private extension SubscriptionPackage {
    init(package: Package) {
        self.init(
            id: package.identifier,
            productIdentifier: package.storeProduct.productIdentifier,
            productType: SubscriptionProductType(packageType: package.packageType),
            title: package.storeProduct.localizedTitle,
            localizedDescription: package.storeProduct.localizedDescription,
            localizedPrice: package.localizedPriceString,
            periodDescription: package.storeProduct.subscriptionPeriod?.localizedDescription,
            revenueCatPackage: package
        )
    }
}

private extension SubscriptionProductType {
    init(packageType: PackageType) {
        switch packageType {
        case .lifetime:
            self = .lifetime
        case .annual:
            self = .yearly
        case .monthly:
            self = .monthly
        case .weekly:
            self = .weekly
        case .custom:
            self = .custom
        default:
            self = .unknown
        }
    }
}

private extension SubscriptionPeriod {
    var localizedDescription: String {
        let unitName: String
        switch unit {
        case .day:
            unitName = value == 1 ? "day" : "days"
        case .week:
            unitName = value == 1 ? "week" : "weeks"
        case .month:
            unitName = value == 1 ? "month" : "months"
        case .year:
            unitName = value == 1 ? "year" : "years"
        @unknown default:
            unitName = "period"
        }
        return "\(value) \(unitName)"
    }
}
