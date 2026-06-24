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
}
