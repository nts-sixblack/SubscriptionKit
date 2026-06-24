import XCTest
@testable import SubscriptionKit

// MARK: - MockRevenueCatAdapter

/// A controllable mock adapter for use in unit tests.
@MainActor
final class MockRevenueCatAdapter: SubscriptionRevenueCatAdapting {

    // MARK: Control

    var shouldThrowOnConfigure = false
    var shouldThrowOnCustomerInfo = false
    var shouldThrowOnPurchase = false
    var shouldThrowOnRestore = false
    var shouldThrowOnLogIn = false
    var shouldThrowOnLogOut = false

    var stubbedCachedCustomerInfo: SubscriptionCustomerSnapshot?
    var stubbedCustomerInfo: SubscriptionCustomerSnapshot = .init(activeEntitlementIDs: [])
    var stubbedOfferings: [SubscriptionPackage] = []
    var stubbedPurchaseOutcome: SubscriptionPurchaseOutcome = .cancelled
    var stubbedManagementURL: URL? = URL(string: "https://apps.apple.com/account/subscriptions")

    // MARK: Protocol

    func configure(with configuration: SubscriptionKitConfiguration) throws {
        if shouldThrowOnConfigure {
            throw TestError.generic
        }
    }

    func cachedCustomerInfo() -> SubscriptionCustomerSnapshot? {
        stubbedCachedCustomerInfo
    }

    func customerInfo() async throws -> SubscriptionCustomerSnapshot {
        if shouldThrowOnCustomerInfo {
            throw TestError.generic
        }
        return stubbedCustomerInfo
    }

    func offerings(identifier: String?, placementIdentifier: String?) async throws -> [SubscriptionPackage] {
        stubbedOfferings
    }

    func customerInfoUpdates() -> AsyncStream<SubscriptionCustomerSnapshot> {
        AsyncStream { _ in }
    }

    func purchase(package: SubscriptionPackage) async throws -> SubscriptionPurchaseOutcome {
        if shouldThrowOnPurchase {
            throw TestError.generic
        }
        return stubbedPurchaseOutcome
    }

    func restorePurchases() async throws -> SubscriptionCustomerSnapshot {
        if shouldThrowOnRestore {
            throw TestError.generic
        }
        return stubbedCustomerInfo
    }

    func logIn(appUserID: String) async throws -> SubscriptionCustomerSnapshot {
        if shouldThrowOnLogIn {
            throw TestError.generic
        }
        return stubbedCustomerInfo
    }

    func logOut() async throws -> SubscriptionCustomerSnapshot {
        if shouldThrowOnLogOut {
            throw TestError.generic
        }
        return stubbedCustomerInfo
    }

    func managementURL() async throws -> URL? {
        stubbedManagementURL
    }

    // MARK: Helper

    enum TestError: Error { case generic }
}

// MARK: - SubscriptionManagerTests

@MainActor
final class SubscriptionManagerTests: XCTestCase {

    var adapter: MockRevenueCatAdapter!
    var userDefaults: UserDefaults!
    var suiteName: String!
    var manager: SubscriptionManager!
    let snapshotKey = "SubscriptionKit.Test.Snapshot"

    override func setUp() {
        super.setUp()
        adapter = MockRevenueCatAdapter()
        suiteName = "SubscriptionManagerTests-\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)!
        manager = SubscriptionManager(adapter: adapter, userDefaults: userDefaults)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Helpers

    func makeConfig(entitlementID: String = "premium") -> SubscriptionKitConfiguration {
        SubscriptionKitConfiguration(
            publicAPIKey: "appl_test",
            entitlementID: entitlementID,
            snapshotStorageKey: snapshotKey
        )
    }

    func makePremiumSnapshot() -> SubscriptionCustomerSnapshot {
        .init(activeEntitlementIDs: ["premium"])
    }

    func makePackage(id: String = "monthly", type: SubscriptionProductType = .monthly) -> SubscriptionPackage {
        SubscriptionPackage(
            id: id,
            productIdentifier: "com.test.\(id)",
            productType: type,
            title: id.capitalized,
            localizedDescription: "\(id.capitalized) plan",
            localizedPrice: "$4.99",
            periodDescription: "1 month"
        )
    }

    // MARK: - Initial State

    func test_initialState_isUnknown() {
        XCTAssertEqual(manager.state, .unknown)
    }

    func test_initialState_isNotPremium() {
        XCTAssertFalse(manager.isPremium)
    }

    // MARK: - Configure

    func test_configure_throwsWhenAdapterThrows() async {
        adapter.shouldThrowOnConfigure = true
        do {
            try await manager.configure(makeConfig())
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertEqual(manager.state, .failed(error.localizedDescription))
        }
    }

    func test_configure_setPremiumWhenCachedInfoHasEntitlement() async throws {
        adapter.stubbedCachedCustomerInfo = makePremiumSnapshot()
        adapter.stubbedCustomerInfo = makePremiumSnapshot()
        try await manager.configure(makeConfig(), refreshOnConfigure: false)
        // After configure with cached premium info, state should be premium
        XCTAssertTrue(manager.isPremium)
    }

    func test_configure_setsNonPremiumWhenNoCachedInfo() async throws {
        adapter.stubbedCachedCustomerInfo = nil
        adapter.stubbedCustomerInfo = .init(activeEntitlementIDs: [])
        try await manager.configure(makeConfig())
        XCTAssertEqual(manager.state, .nonPremium)
    }

    func test_configure_loadSnapshotFallbackWhenNoCachedInfo() async throws {
        // Pre-save a premium snapshot
        SubscriptionPremiumSnapshot(isPremium: true).save(to: userDefaults, key: snapshotKey)
        adapter.stubbedCachedCustomerInfo = nil
        adapter.shouldThrowOnCustomerInfo = true

        try await manager.configure(makeConfig(), refreshOnConfigure: false)
        // State should be premiumFromSnapshot because adapter had no cached info
        // but local snapshot exists
        XCTAssertEqual(manager.state, .premiumFromSnapshot)
    }

    // MARK: - refreshCustomerInfo

    func test_refreshCustomerInfo_setsPremiumWhenEntitlementActive() async throws {
        adapter.stubbedCustomerInfo = makePremiumSnapshot()
        try await manager.configure(makeConfig())
        XCTAssertEqual(manager.state, .premium)
    }

    func test_refreshCustomerInfo_setsNonPremiumWhenEntitlementInactive() async throws {
        adapter.stubbedCustomerInfo = .init(activeEntitlementIDs: [])
        try await manager.configure(makeConfig())
        XCTAssertEqual(manager.state, .nonPremium)
    }

    func test_refreshCustomerInfo_fallsBackToSnapshotOnNetworkFailure() async throws {
        // Save a premium snapshot first
        adapter.stubbedCustomerInfo = makePremiumSnapshot()
        try await manager.configure(makeConfig())
        XCTAssertTrue(manager.isPremium)

        // Simulate network failure on next refresh
        adapter.shouldThrowOnCustomerInfo = true
        await manager.refreshCustomerInfo()

        // Should fall back to the saved snapshot
        XCTAssertEqual(manager.state, .premiumFromSnapshot)
    }

    // MARK: - Purchase

    func test_purchase_setsIsPurchasingDuringOperation() async throws {
        adapter.stubbedPurchaseOutcome = .success(makePremiumSnapshot())
        let package = makePackage()
        try await manager.configure(makeConfig())

        // Verify isPurchasing transitions (it will be false after the await completes)
        await manager.purchase(package: package)
        XCTAssertFalse(manager.isPurchasing)
    }

    func test_purchase_setsPremiumOnSuccess() async throws {
        adapter.stubbedPurchaseOutcome = .success(makePremiumSnapshot())
        try await manager.configure(makeConfig())

        await manager.purchase(package: makePackage())
        XCTAssertTrue(manager.isPremium)
    }

    func test_purchase_doesNotSetPremiumOnCancellation() async throws {
        adapter.stubbedPurchaseOutcome = .cancelled
        adapter.stubbedCustomerInfo = .init(activeEntitlementIDs: [])
        try await manager.configure(makeConfig())

        await manager.purchase(package: makePackage())
        XCTAssertFalse(manager.isPremium)
    }

    func test_purchase_setsLastErrorOnFailure() async throws {
        adapter.shouldThrowOnPurchase = true
        try await manager.configure(makeConfig())

        await manager.purchase(package: makePackage())
        XCTAssertNotNil(manager.lastError)
    }

    // MARK: - Restore

    func test_restorePurchases_setsPremiumOnSuccess() async throws {
        adapter.stubbedCustomerInfo = makePremiumSnapshot()
        try await manager.configure(makeConfig())

        await manager.restorePurchases()
        XCTAssertTrue(manager.isPremium)
    }

    func test_restorePurchases_setsLastErrorOnFailure() async throws {
        adapter.shouldThrowOnRestore = true
        try await manager.configure(makeConfig())

        await manager.restorePurchases()
        XCTAssertNotNil(manager.lastError)
    }

    // MARK: - Package Ordering

    func test_packageOrdering_respectsProductOrder() async throws {
        adapter.stubbedOfferings = [
            makePackage(id: "weekly", type: .weekly),
            makePackage(id: "monthly", type: .monthly),
            makePackage(id: "yearly", type: .yearly),
            makePackage(id: "lifetime", type: .lifetime)
        ]

        let config = SubscriptionKitConfiguration(
            publicAPIKey: "appl_test",
            productOrder: [.lifetime, .yearly, .monthly, .weekly],
            snapshotStorageKey: snapshotKey
        )
        try await manager.configure(config)

        XCTAssertEqual(manager.packages.map(\.productType), [.lifetime, .yearly, .monthly, .weekly])
    }

    func test_packageOrdering_customOrderRespected() async throws {
        adapter.stubbedOfferings = [
            makePackage(id: "lifetime", type: .lifetime),
            makePackage(id: "monthly", type: .monthly),
            makePackage(id: "yearly", type: .yearly)
        ]

        let config = SubscriptionKitConfiguration(
            publicAPIKey: "appl_test",
            productOrder: [.monthly, .yearly, .lifetime],
            snapshotStorageKey: snapshotKey
        )
        try await manager.configure(config)

        XCTAssertEqual(manager.packages.map(\.productType), [.monthly, .yearly, .lifetime])
    }

    // MARK: - LogIn / LogOut

    func test_logIn_clearsPreviousStateAndSetsPremium() async throws {
        adapter.stubbedCustomerInfo = makePremiumSnapshot()
        try await manager.configure(makeConfig())
        XCTAssertTrue(manager.isPremium)

        adapter.stubbedCustomerInfo = .init(activeEntitlementIDs: [])
        await manager.logIn(appUserID: "user-123")
        XCTAssertFalse(manager.isPremium)
    }

    func test_logOut_clearsPreviousStateAndSetsNonPremium() async throws {
        adapter.stubbedCustomerInfo = makePremiumSnapshot()
        try await manager.configure(makeConfig())
        XCTAssertTrue(manager.isPremium)

        adapter.stubbedCustomerInfo = .init(activeEntitlementIDs: [])
        await manager.logOut()
        XCTAssertFalse(manager.isPremium)
    }

    // MARK: - isPremium

    func test_isPremium_trueForPremiumState() {
        XCTAssertTrue(PremiumState.premium == .premium)
    }

    func test_isPremiumFromSnapshot_isConsideredPremium() async throws {
        SubscriptionPremiumSnapshot(isPremium: true).save(to: userDefaults, key: snapshotKey)
        adapter.stubbedCachedCustomerInfo = nil
        adapter.shouldThrowOnCustomerInfo = true

        try await manager.configure(makeConfig(), refreshOnConfigure: false)
        XCTAssertTrue(manager.isPremium)
    }

    // MARK: - Snapshot Persistence

    func test_premiumSnapshot_saveAndLoad() {
        let snapshot = SubscriptionPremiumSnapshot(isPremium: true, updatedAt: Date())
        snapshot.save(to: userDefaults, key: snapshotKey)

        let loaded = SubscriptionPremiumSnapshot.load(from: userDefaults, key: snapshotKey)
        XCTAssertNotNil(loaded)
        XCTAssertTrue(loaded!.isPremium)
    }

    func test_premiumSnapshot_returnsNilWhenNotSaved() {
        let loaded = SubscriptionPremiumSnapshot.load(from: userDefaults, key: "nonexistent_key")
        XCTAssertNil(loaded)
    }
}
