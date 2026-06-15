import Testing
import SwiftUI
@testable import SubscriptionKitExample

struct SubscriptionKitConfigurationTests {
    @Test func emptyAPIKeyFailsValidation() {
        let configuration = SubscriptionKitConfiguration(publicAPIKey: "")

        #expect(throws: SubscriptionKitConfiguration.ValidationError.missingPublicAPIKey) {
            try configuration.validate()
        }
    }

    @Test func defaultsMatchPremiumCustomPaywallPlan() throws {
        let configuration = SubscriptionKitConfiguration(publicAPIKey: "test_key")

        try configuration.validate()

        #expect(configuration.entitlementID == "premium")
        if case .custom = configuration.paywallMode {
            #expect(true)
        } else {
            Issue.record("Expected default paywall mode to be custom.")
        }
        #expect(configuration.productOrder == [.lifetime, .yearly, .monthly, .weekly])
        #expect(configuration.snapshotStorageKey == "SubscriptionKit.PremiumSnapshot")
    }

    @Test func revenueCatPaywallModeIsConfigurable() {
        let configuration = SubscriptionKitConfiguration(
            publicAPIKey: "test_key",
            paywallMode: .revenueCat
        )

        if case .revenueCat = configuration.paywallMode {
            #expect(true)
        } else {
            Issue.record("Expected paywall mode to be RevenueCat.")
        }
    }

    @Test func scrollTemplatePaywallModeCarriesContent() {
        let privacyURL = URL(string: "https://example.com/privacy")!
        let termsURL = URL(string: "https://example.com/terms")!
        let content = SubscriptionScrollTemplatePaywallContent(
            appTitle: "Pose Pro",
            backgroundImage: Image(systemName: "sparkles"),
            backgroundColor: .black,
            heroIcon: Image(systemName: "figure.mind.and.body"),
            headlineSegments: [
                .init(text: "Unlock ", color: .white),
                .init(text: "movement", color: .cyan)
            ],
            subtitle: "Build a daily practice with guided plans.",
            features: [
                .init(icon: Image(systemName: "checkmark.circle.fill"), title: "Premium routines", subtitle: "Fresh sessions every week.")
            ],
            rating: .init(score: "4.9", title: "Loved by members", subtitle: "Built for consistent progress."),
            planSectionTitle: "Choose your plan",
            planOverrides: [
                .init(packageID: "$rc_annual", productIdentifier: nil, title: "Annual", subtitle: "Best value", badge: "Popular")
            ],
            moreInfoRows: [
                .init(title: "Cancel anytime", subtitle: "Manage your plan in App Store settings.")
            ],
            purchaseButtonTitle: "Start Now",
            restoreButtonTitle: "Restore",
            skipButtonTitle: "Not now",
            emptyOfferingTitle: "No plans found",
            emptyOfferingMessage: "Please try again later.",
            legalLinks: [
                .init(title: "Privacy", url: privacyURL),
                .init(title: "Terms", url: termsURL)
            ],
            palette: .init(
                accent: .cyan,
                background: .black,
                foreground: .white,
                secondaryForeground: .gray,
                panelBackground: .white.opacity(0.12),
                planBackground: .white.opacity(0.1),
                selectedPlanBackground: .cyan.opacity(0.2),
                selectedPlanBorder: .cyan,
                bottomBarBackground: .black.opacity(0.94)
            )
        )
        let configuration = SubscriptionKitConfiguration(
            publicAPIKey: "test_key",
            paywallMode: .scrollTemplateView(content: content)
        )

        if case .scrollTemplateView(let carriedContent) = configuration.paywallMode {
            #expect(carriedContent.appTitle == "Pose Pro")
            #expect(carriedContent.headlineSegments.map(\.text) == ["Unlock ", "movement"])
            #expect(carriedContent.features.first?.title == "Premium routines")
            #expect(carriedContent.rating.title == "Loved by members")
            #expect(carriedContent.planOverrides.first?.packageID == "$rc_annual")
            #expect(carriedContent.moreInfoRows.first?.title == "Cancel anytime")
            #expect(carriedContent.purchaseButtonTitle == "Start Now")
            #expect(carriedContent.emptyOfferingMessage == "Please try again later.")
            #expect(carriedContent.legalLinks.map(\.url) == [privacyURL, termsURL])
        } else {
            Issue.record("Expected scroll template paywall mode.")
        }
    }

    @MainActor
    @Test func customProviderFactoryStoresCustomProviderMode() {
        let configuration = SubscriptionKitConfiguration(
            publicAPIKey: "test_key",
            paywallMode: .custom(provider: TestPaywallProvider(title: "Go Pro"))
        )

        if case .customProvider(let provider) = configuration.paywallMode {
            let context = SubscriptionPaywallContext(
                manager: SubscriptionManager(adapter: TestSubscriptionAdapter(), userDefaults: .ephemeral()),
                configuration: configuration,
                dismiss: {}
            )
            _ = provider.makePaywall(context: context)
            #expect(true)
        } else {
            Issue.record("Expected custom provider paywall mode.")
        }
    }

    @MainActor
    @Test func contextPurchaseDismissesAfterPremiumUnlock() async throws {
        let package = SubscriptionPackage.mock(id: "monthly", type: .monthly)
        let adapter = TestSubscriptionAdapter()
        adapter.purchaseResult = .success(.init(activeEntitlementIDs: ["premium"]))
        let manager = SubscriptionManager(adapter: adapter, userDefaults: .ephemeral())
        let configuration = SubscriptionKitConfiguration(publicAPIKey: "test_key")
        try await manager.configure(configuration, refreshOnConfigure: false)
        var dismissCallCount = 0
        let context = SubscriptionPaywallContext(
            manager: manager,
            configuration: configuration,
            dismiss: { dismissCallCount += 1 }
        )

        await context.purchase(package)

        #expect(adapter.purchasedPackageIDs == ["monthly"])
        #expect(manager.isPremium)
        #expect(dismissCallCount == 1)
    }

    @MainActor
    @Test func contextPurchaseDoesNotDismissWithoutPremiumUnlock() async throws {
        let package = SubscriptionPackage.mock(id: "monthly", type: .monthly)
        let adapter = TestSubscriptionAdapter()
        adapter.purchaseResult = .success(.init(activeEntitlementIDs: []))
        let manager = SubscriptionManager(adapter: adapter, userDefaults: .ephemeral())
        let configuration = SubscriptionKitConfiguration(publicAPIKey: "test_key")
        try await manager.configure(configuration, refreshOnConfigure: false)
        var dismissCallCount = 0
        let context = SubscriptionPaywallContext(
            manager: manager,
            configuration: configuration,
            dismiss: { dismissCallCount += 1 }
        )

        await context.purchase(package)

        #expect(adapter.purchasedPackageIDs == ["monthly"])
        #expect(!manager.isPremium)
        #expect(dismissCallCount == 0)
    }

    @MainActor
    @Test func contextRestoreDismissesAfterPremiumUnlock() async throws {
        let adapter = TestSubscriptionAdapter()
        adapter.restoreResult = .success(.init(activeEntitlementIDs: ["premium"]))
        let manager = SubscriptionManager(adapter: adapter, userDefaults: .ephemeral())
        let configuration = SubscriptionKitConfiguration(publicAPIKey: "test_key")
        try await manager.configure(configuration, refreshOnConfigure: false)
        var dismissCallCount = 0
        let context = SubscriptionPaywallContext(
            manager: manager,
            configuration: configuration,
            dismiss: { dismissCallCount += 1 }
        )

        await context.restorePurchases()

        #expect(adapter.restoreCallCount == 1)
        #expect(manager.isPremium)
        #expect(dismissCallCount == 1)
    }

    @MainActor
    @Test func contextRestoreDoesNotDismissWithoutPremiumUnlock() async throws {
        let adapter = TestSubscriptionAdapter()
        adapter.restoreResult = .success(.init(activeEntitlementIDs: []))
        let manager = SubscriptionManager(adapter: adapter, userDefaults: .ephemeral())
        let configuration = SubscriptionKitConfiguration(publicAPIKey: "test_key")
        try await manager.configure(configuration, refreshOnConfigure: false)
        var dismissCallCount = 0
        let context = SubscriptionPaywallContext(
            manager: manager,
            configuration: configuration,
            dismiss: { dismissCallCount += 1 }
        )

        await context.restorePurchases()

        #expect(adapter.restoreCallCount == 1)
        #expect(!manager.isPremium)
        #expect(dismissCallCount == 0)
    }
}

private struct TestPaywallProvider: SubscriptionCustomPaywallProviding {
    let title: String

    func makePaywall(context: SubscriptionPaywallContext) -> some View {
        Text(title)
    }
}

@MainActor
private final class TestSubscriptionAdapter: SubscriptionRevenueCatAdapting {
    var customerInfoResult: Result<SubscriptionCustomerSnapshot, Error> = .success(.init(activeEntitlementIDs: []))
    var offeringResult: Result<[SubscriptionPackage], Error> = .success([])
    var purchaseResult: Result<SubscriptionCustomerSnapshot, Error> = .success(.init(activeEntitlementIDs: []))
    var restoreResult: Result<SubscriptionCustomerSnapshot, Error> = .success(.init(activeEntitlementIDs: []))
    var purchasedPackageIDs: [String] = []
    var restoreCallCount = 0

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
        return .success(try purchaseResult.get())
    }
    func restorePurchases() async throws -> SubscriptionCustomerSnapshot {
        restoreCallCount += 1
        return try restoreResult.get()
    }
    func logIn(appUserID: String) async throws -> SubscriptionCustomerSnapshot {
        .init(activeEntitlementIDs: [])
    }
    func logOut() async throws -> SubscriptionCustomerSnapshot {
        .init(activeEntitlementIDs: [])
    }
    func managementURL() async throws -> URL? {
        nil
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
        UserDefaults(suiteName: "SubscriptionKitConfigurationTests.\(UUID().uuidString)")!
    }
}
