import Foundation

// MARK: - PremiumState

/// The current subscription / premium state tracked by ``SubscriptionManager``.
public enum PremiumState: Equatable {
    /// Manager has not loaded a reliable subscription state yet.
    case unknown
    /// Customer info is being fetched from RevenueCat.
    case loading
    /// RevenueCat returned an active entitlement matching the configured `entitlementID`.
    case premium
    /// RevenueCat state was unavailable, but the local snapshot indicates the user
    /// was premium previously. Treated as premium for UX continuity.
    case premiumFromSnapshot
    /// No active configured entitlement was found.
    case nonPremium
    /// Configuration or refresh failed and no fallback could be applied.
    case failed(String)
}

// MARK: - SubscriptionProductType

/// Maps RevenueCat `PackageType` to a framework-agnostic product type.
public enum SubscriptionProductType: String, Codable, CaseIterable, Equatable, Hashable {
    case lifetime
    case yearly
    case monthly
    case weekly
    case custom
    case unknown
}

// MARK: - SubscriptionCustomerSnapshot

/// A lightweight, framework-agnostic snapshot of RevenueCat `CustomerInfo`.
public struct SubscriptionCustomerSnapshot: Equatable {
    /// The set of active entitlement identifiers.
    public var activeEntitlementIDs: Set<String>
    /// Apple's subscription management URL for this customer, if available.
    public var managementURL: URL?

    public init(activeEntitlementIDs: Set<String>, managementURL: URL? = nil) {
        self.activeEntitlementIDs = activeEntitlementIDs
        self.managementURL = managementURL
    }
}

// MARK: - SubscriptionPremiumSnapshot

/// A `UserDefaults`-backed cache of the last known premium state.
///
/// Used as an offline/cold-start fallback when RevenueCat is unavailable.
public struct SubscriptionPremiumSnapshot: Codable, Equatable {
    /// Whether the user was premium at the time the snapshot was taken.
    public var isPremium: Bool
    /// The date this snapshot was recorded.
    public var updatedAt: Date

    public init(isPremium: Bool, updatedAt: Date = .now) {
        self.isPremium = isPremium
        self.updatedAt = updatedAt
    }

    /// Persists this snapshot to `UserDefaults`.
    public func save(to userDefaults: UserDefaults, key: String) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        userDefaults.set(data, forKey: key)
    }

    /// Loads a snapshot from `UserDefaults`, returning `nil` if none exists.
    public static func load(from userDefaults: UserDefaults, key: String) -> SubscriptionPremiumSnapshot? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SubscriptionPremiumSnapshot.self, from: data)
    }
}

// MARK: - SubscriptionPackage

/// A framework-agnostic representation of a RevenueCat `Package`.
public struct SubscriptionPackage: Identifiable, Equatable {
    /// The RevenueCat package identifier.
    public let id: String
    /// The underlying App Store product identifier.
    public let productIdentifier: String
    /// The product type derived from RevenueCat `PackageType`.
    public let productType: SubscriptionProductType
    /// The localized product title from the App Store.
    public let title: String
    /// The localized product description from the App Store.
    public let localizedDescription: String
    /// The formatted, localized price string (e.g. `"$4.99"`).
    public let localizedPrice: String
    /// A human-readable subscription period (e.g. `"1 month"`), `nil` for non-consumables.
    public let periodDescription: String?
    /// The underlying RevenueCat `Package` object. Opaque to callers outside the adapter.
    public let revenueCatPackage: Any?

    public init(
        id: String,
        productIdentifier: String,
        productType: SubscriptionProductType,
        title: String,
        localizedDescription: String,
        localizedPrice: String,
        periodDescription: String?,
        revenueCatPackage: Any? = nil
    ) {
        self.id = id
        self.productIdentifier = productIdentifier
        self.productType = productType
        self.title = title
        self.localizedDescription = localizedDescription
        self.localizedPrice = localizedPrice
        self.periodDescription = periodDescription
        self.revenueCatPackage = revenueCatPackage
    }

    public static func == (lhs: SubscriptionPackage, rhs: SubscriptionPackage) -> Bool {
        lhs.id == rhs.id &&
        lhs.productIdentifier == rhs.productIdentifier &&
        lhs.productType == rhs.productType &&
        lhs.title == rhs.title &&
        lhs.localizedDescription == rhs.localizedDescription &&
        lhs.localizedPrice == rhs.localizedPrice &&
        lhs.periodDescription == rhs.periodDescription
    }
}

// MARK: - SubscriptionPurchaseOutcome

/// The result of a purchase attempt.
public enum SubscriptionPurchaseOutcome: Equatable {
    /// The purchase completed successfully.
    case success(SubscriptionCustomerSnapshot)
    /// The user cancelled the purchase without completing it.
    case cancelled
}
