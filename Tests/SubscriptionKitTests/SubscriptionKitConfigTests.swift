import XCTest
import SwiftInjected
@testable import SubscriptionKit

final class SubscriptionKitConfigTests: XCTestCase {

    // MARK: - Validation

    func test_validate_throwsWhenPublicAPIKeyIsEmpty() {
        let config = SubscriptionKitConfiguration(publicAPIKey: "")
        XCTAssertThrowsError(try config.validate()) { error in
            XCTAssertEqual(error as? SubscriptionKitConfiguration.ValidationError, .missingPublicAPIKey)
        }
    }

    func test_validate_throwsWhenPublicAPIKeyIsWhitespace() {
        let config = SubscriptionKitConfiguration(publicAPIKey: "   ")
        XCTAssertThrowsError(try config.validate()) { error in
            XCTAssertEqual(error as? SubscriptionKitConfiguration.ValidationError, .missingPublicAPIKey)
        }
    }

    func test_validate_succeedsWithNonEmptyAPIKey() {
        let config = SubscriptionKitConfiguration(publicAPIKey: "appl_test_key")
        XCTAssertNoThrow(try config.validate())
    }

    // MARK: - Defaults

    func test_defaults_entitlementID() {
        let config = SubscriptionKitConfiguration(publicAPIKey: "key")
        XCTAssertEqual(config.entitlementID, "premium")
    }

    func test_defaults_productOrder() {
        let config = SubscriptionKitConfiguration(publicAPIKey: "key")
        XCTAssertEqual(config.productOrder, [.lifetime, .yearly, .monthly, .weekly])
    }

    func test_defaults_showsCloseButton() {
        let config = SubscriptionKitConfiguration(publicAPIKey: "key")
        XCTAssertTrue(config.showsCloseButton)
    }

    func test_defaults_showsRestoreButton() {
        let config = SubscriptionKitConfiguration(publicAPIKey: "key")
        XCTAssertTrue(config.showsRestoreButton)
    }

    func test_defaults_debugLoggingDisabled() {
        let config = SubscriptionKitConfiguration(publicAPIKey: "key")
        XCTAssertFalse(config.debugLoggingEnabled)
    }

    func test_defaults_snapshotStorageKey() {
        let config = SubscriptionKitConfiguration(publicAPIKey: "key")
        XCTAssertEqual(config.snapshotStorageKey, "SubscriptionKit.PremiumSnapshot")
    }

    func test_defaults_defaultSelectedProductIsNil() {
        let config = SubscriptionKitConfiguration(publicAPIKey: "key")
        XCTAssertNil(config.defaultSelectedProduct)
    }

    // MARK: - resolvedDefaultPackage

    func test_resolvedDefaultPackage_returnsFirstWhenDefaultIsNil() {
        let config = SubscriptionKitConfiguration(publicAPIKey: "key")
        let packages = [
            makePackage(id: "lifetime", type: .lifetime),
            makePackage(id: "yearly", type: .yearly)
        ]

        XCTAssertEqual(config.resolvedDefaultPackage(from: packages)?.id, "lifetime")
    }

    func test_resolvedDefaultPackage_selectsMatchingProductType() {
        let config = SubscriptionKitConfiguration(
            publicAPIKey: "key",
            defaultSelectedProduct: .yearly
        )
        let packages = [
            makePackage(id: "lifetime", type: .lifetime),
            makePackage(id: "yearly", type: .yearly)
        ]

        XCTAssertEqual(config.resolvedDefaultPackage(from: packages)?.id, "yearly")
    }

    func test_resolvedDefaultPackage_fallsBackToFirstWhenTypeNotFound() {
        let config = SubscriptionKitConfiguration(
            publicAPIKey: "key",
            defaultSelectedProduct: .weekly
        )
        let packages = [
            makePackage(id: "lifetime", type: .lifetime),
            makePackage(id: "yearly", type: .yearly)
        ]

        XCTAssertEqual(config.resolvedDefaultPackage(from: packages)?.id, "lifetime")
    }

    func test_resolvedDefaultPackage_returnsNilForEmptyPackages() {
        let config = SubscriptionKitConfiguration(publicAPIKey: "key")
        XCTAssertNil(config.resolvedDefaultPackage(from: []))
    }

    // MARK: - ValidationError localized description

    func test_validationError_localizedDescription() {
        let error = SubscriptionKitConfiguration.ValidationError.missingPublicAPIKey
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    @MainActor
    func test_subscriptionPaywallView_init_withOnDismiss() {
        let _ = Dependencies {
            Dependency { SubscriptionManager() }
        }.build()

        var called = false
        let view = SubscriptionPaywallView(onDismiss: {
            called = true
        })
        XCTAssertNotNil(view)
    }

    private func makePackage(id: String, type: SubscriptionProductType) -> SubscriptionPackage {
        SubscriptionPackage(
            id: id,
            productIdentifier: "com.test.\(id)",
            productType: type,
            title: id.capitalized,
            localizedDescription: "\(id.capitalized) plan",
            localizedPrice: "$4.99",
            periodDescription: nil
        )
    }
}
