import Combine
import Foundation
import SwiftUI

// MARK: - SubscriptionManagerError

/// Errors produced by ``SubscriptionManager`` during runtime operations.
public enum SubscriptionManagerError: Error, LocalizedError, Equatable {
    /// The package was not backed by a RevenueCat package object and cannot be purchased.
    case packageMissingRevenueCatBacking
    /// No subscription management URL is available yet (customer info not loaded).
    case manageSubscriptionURLUnavailable

    public var errorDescription: String? {
        switch self {
        case .packageMissingRevenueCatBacking:
            return "This package cannot be purchased because it is not backed by a RevenueCat package."
        case .manageSubscriptionURLUnavailable:
            return "No subscription management URL is available yet."
        }
    }
}

// MARK: - SubscriptionManager

/// The central subscription state manager.
///
/// Use the shared singleton or create your own instance for testing.
///
/// ```swift
/// @StateObject private var subscriptionManager = SubscriptionManager.shared
///
/// // Configure once at app launch
/// .task {
///     try? await subscriptionManager.configure(config)
/// }
///
/// // Gate premium content
/// if subscriptionManager.isPremium {
///     PremiumFeatureView()
/// }
/// ```
@MainActor
public final class SubscriptionManager: ObservableObject {

    // MARK: - Shared

    /// Shared singleton instance. Suitable for most apps.
    public static let shared = SubscriptionManager()

    // MARK: - Published State

    /// The current premium / subscription state.
    @Published public private(set) var state: PremiumState = .unknown
    /// Packages loaded from RevenueCat and sorted by `productOrder`.
    @Published public private(set) var packages: [SubscriptionPackage] = []
    /// All packages from the selected offering (same as `packages`).
    @Published public private(set) var offerings: [SubscriptionPackage] = []
    /// The last error produced by a purchase, restore, or refresh operation.
    @Published public private(set) var lastError: Error?
    /// `true` while a purchase transaction is in progress.
    @Published public private(set) var isPurchasing = false
    /// `true` while purchases are being restored.
    @Published public private(set) var isRestoring = false

    // MARK: - Computed

    /// `true` when `state` is `.premium` or `.premiumFromSnapshot`.
    public var isPremium: Bool {
        state == .premium || state == .premiumFromSnapshot
    }

    // MARK: - Private

    private let adapter: SubscriptionRevenueCatAdapting
    private let userDefaults: UserDefaults
    @Published public private(set) var configuration: SubscriptionKitConfiguration?
    private var streamTask: Task<Void, Never>?

    // MARK: - Init

    /// Creates a manager with optional custom adapter and `UserDefaults` store.
    ///
    /// - Parameters:
    ///   - adapter: RevenueCat adapter. Defaults to the live `RevenueCatSubscriptionAdapter`.
    ///   - userDefaults: Defaults store for premium snapshot persistence. Defaults to `.standard`.
    public init(
        adapter: SubscriptionRevenueCatAdapting? = nil,
        userDefaults: UserDefaults = .standard
    ) {
        self.adapter = adapter ?? RevenueCatSubscriptionAdapter()
        self.userDefaults = userDefaults
    }

    deinit {
        streamTask?.cancel()
    }

    // MARK: - Configuration

    public func setConfiguration(_ configuration: SubscriptionKitConfiguration) {
        self.configuration = configuration
    }

    /// Configures the SDK and begins listening for entitlement updates.
    ///
    /// Call this once near app launch, typically inside a `.task` modifier on the root view.
    ///
    /// - Parameters:
    ///   - configuration: The kit configuration.
    ///   - refreshOnConfigure: If `true`, fetches fresh customer info after setup. Defaults to `true`.
    /// - Throws: ``SubscriptionKitConfiguration/ValidationError`` if the configuration is invalid.
    public func configure(
        _ configuration: SubscriptionKitConfiguration,
        refreshOnConfigure: Bool = true
    ) async throws {
        NSLog("SubscriptionManager.configure called with configuration: \(configuration)")
        self.configuration = configuration
        lastError = nil
        if state == .unknown {
            state = .loading
        }

        do {
            try adapter.configure(with: configuration)
        } catch {
            state = .failed(error.localizedDescription)
            lastError = error
            throw error
        }

        if let cached = adapter.cachedCustomerInfo() {
            apply(customerInfo: cached, source: .revenueCat)
        } else if let snapshot = SubscriptionPremiumSnapshot.load(from: userDefaults, key: configuration.snapshotStorageKey) {
            state = snapshot.isPremium ? .premiumFromSnapshot : .nonPremium
        }

        await refreshOfferings()
        subscribeToCustomerInfoStream()

        if refreshOnConfigure {
            await refreshCustomerInfo()
        }
    }

    /// Fire-and-forget version of ``configure(_:refreshOnConfigure:)``.
    ///
    /// Errors are silently discarded. Prefer the `async throws` variant in production.
    public func configure(_ configuration: SubscriptionKitConfiguration) {
        Task {
            try? await configure(configuration, refreshOnConfigure: true)
        }
    }

    // MARK: - Customer Info

    /// Fetches fresh customer info and updates the state.
    public func refreshCustomerInfo() async {
        guard configuration != nil else { return }
        if state == .unknown {
            state = .loading
        }

        do {
            let customerInfo = try await adapter.customerInfo()
            apply(customerInfo: customerInfo, source: .revenueCat)
        } catch {
            lastError = error
            if state == .loading || state == .unknown {
                loadLocalSnapshotFallback()
            }
        }
    }

    // MARK: - Purchase

    /// Purchases the given package.
    ///
    /// Sets `isPurchasing` to `true` for the duration of the operation.
    /// Updates `state` and `lastError` based on the outcome.
    public func purchase(package: SubscriptionPackage) async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            switch try await adapter.purchase(package: package) {
            case .success(let customerInfo):
                apply(customerInfo: customerInfo, source: .revenueCat)
                lastError = nil
            case .cancelled:
                break
            }
        } catch {
            lastError = error
        }
    }

    // MARK: - Restore

    /// Restores previous purchases and updates `state`.
    public func restorePurchases() async {
        isRestoring = true
        defer { isRestoring = false }

        do {
            let customerInfo = try await adapter.restorePurchases()
            apply(customerInfo: customerInfo, source: .revenueCat)
            lastError = nil
        } catch {
            lastError = error
        }
    }

    // MARK: - Auth

    /// Logs in with an app-supplied user ID and refreshes state.
    ///
    /// Call this after your own authentication succeeds.
    public func logIn(appUserID: String) async {
        clearRevenueCatState()

        do {
            let customerInfo = try await adapter.logIn(appUserID: appUserID)
            apply(customerInfo: customerInfo, source: .revenueCat)
            await refreshOfferings()
            lastError = nil
        } catch {
            lastError = error
        }
    }

    /// Logs out the current user and refreshes state.
    ///
    /// Call this after your own sign-out flow.
    public func logOut() async {
        clearRevenueCatState()

        do {
            let customerInfo = try await adapter.logOut()
            apply(customerInfo: customerInfo, source: .revenueCat)
            await refreshOfferings()
            lastError = nil
        } catch {
            lastError = error
        }
    }

    // MARK: - Subscription Management

    /// Opens Apple's subscription management sheet for the current user.
    public func openManageSubscriptionURL() async {
        do {
            guard let url = try await adapter.managementURL() else {
                throw SubscriptionManagerError.manageSubscriptionURLUnavailable
            }
            await UIApplication.shared.open(url)
            lastError = nil
        } catch {
            lastError = error
        }
    }

    // MARK: - Private Helpers

    private enum CustomerInfoSource {
        case revenueCat
        case snapshot
    }

    private func apply(customerInfo: SubscriptionCustomerSnapshot, source: CustomerInfoSource) {
        guard let configuration else { return }
        let premium = customerInfo.activeEntitlementIDs.contains(configuration.entitlementID)
        state = premium ? (source == .snapshot ? .premiumFromSnapshot : .premium) : .nonPremium
        SubscriptionPremiumSnapshot(isPremium: premium).save(to: userDefaults, key: configuration.snapshotStorageKey)
    }

    private func loadLocalSnapshotFallback() {
        guard let configuration,
              let snapshot = SubscriptionPremiumSnapshot.load(from: userDefaults, key: configuration.snapshotStorageKey) else {
            if let lastError {
                state = .failed(lastError.localizedDescription)
            }
            return
        }
        state = snapshot.isPremium ? .premiumFromSnapshot : .nonPremium
    }

    /// Fetches the latest offerings and packages from RevenueCat.
    public func refreshOfferings() async {
        guard let configuration else { return }

        do {
            let returnedPackages = try await adapter.offerings(
                identifier: configuration.offeringIdentifier,
                placementIdentifier: configuration.placementIdentifier
            )
            NSLog("SubscriptionManager: Fetched \(returnedPackages.count) packages from RevenueCat.")
            packages = sort(packages: returnedPackages, order: configuration.productOrder)
            offerings = packages
            if returnedPackages.isEmpty {
                NSLog("SubscriptionManager: Packages array is empty. Ensure your products are configured in App Store Connect / StoreKit Configuration file, and the bundle ID matches.")
            }
        } catch {
            NSLog("SubscriptionManager: Error fetching offerings: \(error)")
            lastError = error
        }
    }

    private func sort(packages: [SubscriptionPackage], order: [SubscriptionProductType]) -> [SubscriptionPackage] {
        packages.sorted { lhs, rhs in
            let lhsIndex = order.firstIndex(of: lhs.productType) ?? order.endIndex
            let rhsIndex = order.firstIndex(of: rhs.productType) ?? order.endIndex
            if lhsIndex == rhsIndex {
                return lhs.localizedPrice < rhs.localizedPrice
            }
            return lhsIndex < rhsIndex
        }
    }

    private func subscribeToCustomerInfoStream() {
        streamTask?.cancel()
        streamTask = Task { [weak self] in
            guard let self else { return }
            for await customerInfo in adapter.customerInfoUpdates() {
                self.apply(customerInfo: customerInfo, source: .revenueCat)
            }
        }
    }

    private func clearRevenueCatState() {
        state = .unknown
        packages = []
        offerings = []
        lastError = nil
    }
}
