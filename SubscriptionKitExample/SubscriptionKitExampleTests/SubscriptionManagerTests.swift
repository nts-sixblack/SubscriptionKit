import Foundation
import Testing
@testable import SubscriptionKitExample

@MainActor
struct SubscriptionManagerTests {
    @Test func activeEntitlementMapsToPremium() async throws {
        let adapter = MockSubscriptionAdapter()
        adapter.customerInfoResult = .success(.init(activeEntitlementIDs: ["premium"]))
        let manager = SubscriptionManager(adapter: adapter, userDefaults: .ephemeral())

        try await manager.configure(.test())

        #expect(manager.state == .premium)
        #expect(manager.isPremium)
    }

    @Test(arguments: [
        SubscriptionCustomerSnapshot(activeEntitlementIDs: []),
        SubscriptionCustomerSnapshot(activeEntitlementIDs: ["pro"])
    ])
    func inactiveOrMissingEntitlementMapsToNonPremium(snapshot: SubscriptionCustomerSnapshot) async throws {
        let adapter = MockSubscriptionAdapter()
        adapter.customerInfoResult = .success(snapshot)
        let manager = SubscriptionManager(adapter: adapter, userDefaults: .ephemeral())

        try await manager.configure(.test())

        #expect(manager.state == .nonPremium)
        #expect(!manager.isPremium)
    }

    @Test func packagesAreSortedByConfiguredProductOrderAndKeepLifetime() async throws {
        let adapter = MockSubscriptionAdapter()
        adapter.offeringResult = .success([
            .mock(id: "weekly", type: .weekly),
            .mock(id: "monthly", type: .monthly),
            .mock(id: "lifetime", type: .lifetime),
            .mock(id: "yearly", type: .yearly)
        ])
        let manager = SubscriptionManager(adapter: adapter, userDefaults: .ephemeral())

        try await manager.configure(.test())

        #expect(manager.packages.map(\.productType) == [.lifetime, .yearly, .monthly, .weekly])
        #expect(manager.packages.contains { $0.productType == .lifetime })
    }

    @Test func cachedSnapshotIsUsedBeforeNetworkAndNetworkReplacesIt() async throws {
        let defaults = UserDefaults.ephemeral()
        SubscriptionPremiumSnapshot(isPremium: true).save(to: defaults, key: "snapshot")
        let adapter = MockSubscriptionAdapter()
        adapter.customerInfoResult = .success(.init(activeEntitlementIDs: []))
        let manager = SubscriptionManager(adapter: adapter, userDefaults: defaults)

        try await manager.configure(.test(snapshotStorageKey: "snapshot"), refreshOnConfigure: false)
        #expect(manager.state == .premiumFromSnapshot)

        await manager.refreshCustomerInfo()

        #expect(manager.state == .nonPremium)
        #expect(SubscriptionPremiumSnapshot.load(from: defaults, key: "snapshot")?.isPremium == false)
    }

    @Test func failedRefreshKeepsLocalSnapshotFallbackWhenNoRevenueCatStateExists() async throws {
        let defaults = UserDefaults.ephemeral()
        SubscriptionPremiumSnapshot(isPremium: true).save(to: defaults, key: "snapshot")
        let adapter = MockSubscriptionAdapter()
        adapter.customerInfoResult = .failure(TestError.network)
        let manager = SubscriptionManager(adapter: adapter, userDefaults: defaults)

        try await manager.configure(.test(snapshotStorageKey: "snapshot"))

        #expect(manager.state == .premiumFromSnapshot)
        #expect(manager.lastError != nil)
    }

    @Test func purchaseSuccessUpdatesPremiumState() async throws {
        let package = SubscriptionPackage.mock(id: "monthly", type: .monthly)
        let adapter = MockSubscriptionAdapter()
        adapter.purchaseResult = .success(.init(activeEntitlementIDs: ["premium"]))
        let manager = SubscriptionManager(adapter: adapter, userDefaults: .ephemeral())
        try await manager.configure(.test(), refreshOnConfigure: false)

        await manager.purchase(package: package)

        #expect(adapter.purchasedPackageIDs == ["monthly"])
        #expect(manager.state == .premium)
    }

    @Test func purchaseCancellationDoesNotChangePremiumState() async throws {
        let package = SubscriptionPackage.mock(id: "monthly", type: .monthly)
        let adapter = MockSubscriptionAdapter()
        adapter.purchaseResult = .success(.init(activeEntitlementIDs: ["premium"]))
        adapter.purchaseCancelled = true
        let manager = SubscriptionManager(adapter: adapter, userDefaults: .ephemeral())
        try await manager.configure(.test(), refreshOnConfigure: false)

        await manager.purchase(package: package)

        #expect(manager.state == .unknown)
        #expect(manager.lastError == nil)
    }

    @Test func purchaseErrorDoesNotChangePremiumState() async throws {
        let package = SubscriptionPackage.mock(id: "monthly", type: .monthly)
        let adapter = MockSubscriptionAdapter()
        adapter.purchaseResult = .failure(TestError.network)
        let manager = SubscriptionManager(adapter: adapter, userDefaults: .ephemeral())
        try await manager.configure(.test(), refreshOnConfigure: false)

        await manager.purchase(package: package)

        #expect(manager.state == .unknown)
        #expect(manager.lastError != nil)
    }

    @Test func restoreSuccessUpdatesPremiumState() async throws {
        let adapter = MockSubscriptionAdapter()
        adapter.restoreResult = .success(.init(activeEntitlementIDs: ["premium"]))
        let manager = SubscriptionManager(adapter: adapter, userDefaults: .ephemeral())
        try await manager.configure(.test(), refreshOnConfigure: false)

        await manager.restorePurchases()

        #expect(adapter.restoreCallCount == 1)
        #expect(manager.state == .premium)
    }

    @Test func identityChangesClearStaleStateAndRefresh() async throws {
        let adapter = MockSubscriptionAdapter()
        adapter.customerInfoResult = .success(.init(activeEntitlementIDs: ["premium"]))
        adapter.logInResult = .success(.init(activeEntitlementIDs: []))
        adapter.logOutResult = .success(.init(activeEntitlementIDs: ["premium"]))
        let manager = SubscriptionManager(adapter: adapter, userDefaults: .ephemeral())
        try await manager.configure(.test())
        #expect(manager.state == .premium)

        await manager.logIn(appUserID: "new-user")
        #expect(adapter.loggedInIDs == ["new-user"])
        #expect(manager.state == .nonPremium)

        await manager.logOut()
        #expect(adapter.logOutCallCount == 1)
        #expect(manager.state == .premium)
    }
}

private enum TestError: Error {
    case network
}

@MainActor
private final class MockSubscriptionAdapter: SubscriptionRevenueCatAdapting {
    var customerInfoResult: Result<SubscriptionCustomerSnapshot, Error> = .success(.init(activeEntitlementIDs: []))
    var offeringResult: Result<[SubscriptionPackage], Error> = .success([])
    var purchaseResult: Result<SubscriptionCustomerSnapshot, Error> = .success(.init(activeEntitlementIDs: []))
    var restoreResult: Result<SubscriptionCustomerSnapshot, Error> = .success(.init(activeEntitlementIDs: []))
    var logInResult: Result<SubscriptionCustomerSnapshot, Error> = .success(.init(activeEntitlementIDs: []))
    var logOutResult: Result<SubscriptionCustomerSnapshot, Error> = .success(.init(activeEntitlementIDs: []))
    var purchaseCancelled = false
    var purchasedPackageIDs: [String] = []
    var restoreCallCount = 0
    var loggedInIDs: [String] = []
    var logOutCallCount = 0

    func configure(with configuration: SubscriptionKitConfiguration) throws {}
    func cachedCustomerInfo() -> SubscriptionCustomerSnapshot? { nil }
    func customerInfo() async throws -> SubscriptionCustomerSnapshot { try customerInfoResult.get() }
    func offerings(identifier: String?, placementIdentifier: String?) async throws -> [SubscriptionPackage] {
        try offeringResult.get()
    }
    func customerInfoUpdates() -> AsyncStream<SubscriptionCustomerSnapshot> {
        AsyncStream { continuation in continuation.finish() }
    }
    func purchase(package: SubscriptionPackage) async throws -> SubscriptionPurchaseOutcome {
        purchasedPackageIDs.append(package.id)
        if purchaseCancelled {
            return .cancelled
        }
        return .success(try purchaseResult.get())
    }
    func restorePurchases() async throws -> SubscriptionCustomerSnapshot {
        restoreCallCount += 1
        return try restoreResult.get()
    }
    func logIn(appUserID: String) async throws -> SubscriptionCustomerSnapshot {
        loggedInIDs.append(appUserID)
        return try logInResult.get()
    }
    func logOut() async throws -> SubscriptionCustomerSnapshot {
        logOutCallCount += 1
        return try logOutResult.get()
    }
    func managementURL() async throws -> URL? {
        nil
    }
}

private extension SubscriptionKitConfiguration {
    static func test(snapshotStorageKey: String = "SubscriptionKitTests.Snapshot") -> SubscriptionKitConfiguration {
        SubscriptionKitConfiguration(
            publicAPIKey: "test_key",
            snapshotStorageKey: snapshotStorageKey
        )
    }
}

private extension SubscriptionPackage {
    static func mock(id: String, type: SubscriptionProductType) -> SubscriptionPackage {
        SubscriptionPackage(
            id: id,
            productIdentifier: "product.\(id)",
            productType: type,
            title: id.capitalized,
            localizedDescription: "\(id.capitalized) access",
            localizedPrice: "$1.99",
            periodDescription: nil
        )
    }
}

private extension UserDefaults {
    static func ephemeral() -> UserDefaults {
        let defaults = UserDefaults(suiteName: "SubscriptionKitTests.\(UUID().uuidString)")!
        defaults.removePersistentDomain(forName: defaultsSuiteName(defaults))
        return defaults
    }

    static func defaultsSuiteName(_ defaults: UserDefaults) -> String {
        defaults.dictionaryRepresentation()["NSArgumentDomain"] as? String ?? "unused"
    }
}
