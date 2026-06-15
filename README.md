# SubscriptionKit

A lightweight Swift Package Manager library that wraps **RevenueCat** into a clean, testable subscription layer for iOS apps.

SubscriptionKit gives you:
- A single `SubscriptionManager` to track premium state, purchase, restore, and manage users.
- Four paywall modes: RevenueCat hosted, built-in custom SwiftUI, scroll template, and fully custom provider.
- Offline-resilient premium state via `UserDefaults` snapshot fallback.
- A testable adapter protocol for unit testing without the real RevenueCat SDK.
- Full DocC documentation on every public type.

---

## Requirements

| Requirement | Version |
|---|---|
| iOS | 16.0+ |
| Xcode | 15.0+ |
| Swift | 5.9+ |
| RevenueCat SDK | 5.0+ |

---

## Installation

### Swift Package Manager — Xcode

1. Open your project in Xcode.
2. Go to **File → Add Package Dependencies…**
3. Enter the repository URL:

```
https://github.com/nts-sixblack/SubscriptionKit.git
```

4. Select **Up to Next Major Version** from `1.0.0`.
5. Add **SubscriptionKit** to your app target.

### Swift Package Manager — Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/nts-sixblack/SubscriptionKit.git", from: "1.0.0")
],
targets: [
    .target(
        name: "MyApp",
        dependencies: ["SubscriptionKit"]
    )
]
```

> **Note**: SubscriptionKit automatically brings in `RevenueCat` and `RevenueCatUI` as transitive dependencies. You do not need to add them separately.

---

## Quick Start

### 1. Import and configure

```swift
import SubscriptionKit
import SwiftUI
import SwiftInjected

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 1. Configure dependencies
        let dependencies = Dependencies {
            Dependency { SubscriptionManager.shared }
        }
        dependencies.build()

        // 2. Setup Configuration
        let config = SubscriptionKitConfiguration(
            publicAPIKey: "appl_your_revenuecat_ios_key",
            entitlementID: "premium",
            paywallMode: .custom
        )
        SubscriptionManager.shared.setConfiguration(config)
        
        // 3. Start configuring RevenueCat
        Task {
            try? await SubscriptionManager.shared.configure(config)
        }

        return true
    }
}

@main
struct MyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 2. Gate premium features

```swift
struct ContentView: View {
    @InjectedObservable var subscriptionManager: SubscriptionManager

    var body: some View {
        if subscriptionManager.isPremium {
            PremiumFeatureView()
        } else {
            LockedFeatureView()
        }
    }
}
```

### 3. Present a paywall

```swift
struct LockedFeatureView: View {
    @State private var isShowingPaywall = false

    var body: some View {
        Button("Unlock Premium") {
            isShowingPaywall = true
        }
        .sheet(isPresented: $isShowingPaywall) {
            SubscriptionPaywallView()
        }
    }
}
```

---

## Configuration Reference

All configuration lives in `SubscriptionKitConfiguration`.

| Property | Type | Default | Description |
|---|---|---|---|
| `publicAPIKey` | `String` | **Required** | RevenueCat public SDK key. Use iOS platform key for production, Test Store key only for development. |
| `entitlementID` | `String` | `"premium"` | RevenueCat entitlement identifier. Must match the entitlement in the RevenueCat dashboard. |
| `appUserID` | `String?` | `nil` | Stable user ID for authenticated users. If `nil`, RevenueCat uses an anonymous ID. |
| `paywallMode` | `PaywallMode` | `.custom` | Selects the paywall implementation. |
| `offeringIdentifier` | `String?` | `nil` | RevenueCat offering ID. If `nil`, falls back to `placementIdentifier` then current offering. |
| `placementIdentifier` | `String?` | `nil` | RevenueCat targeting placement ID. Used only when `offeringIdentifier` is `nil`. |
| `productOrder` | `[SubscriptionProductType]` | `[.lifetime, .yearly, .monthly, .weekly]` | Sort order for packages in built-in paywalls. |
| `customPaywall` | `SubscriptionCustomPaywallContent` | `.default` | Copy for the built-in custom SwiftUI paywall. |
| `showsCloseButton` | `Bool` | `true` | Shows a close/skip button in the paywall. |
| `showsRestoreButton` | `Bool` | `true` | Shows a restore purchases button in built-in paywalls. |
| `theme` | `SubscriptionPaywallTheme` | `.default` | Colors for the built-in custom SwiftUI paywall. |
| `debugLoggingEnabled` | `Bool` | `false` | Enables `Purchases.logLevel = .debug`. Keep `false` in production. |
| `snapshotStorageKey` | `String` | `"SubscriptionKit.PremiumSnapshot"` | `UserDefaults` key for the premium state cache. |

Validation: `publicAPIKey` cannot be empty or whitespace — `configure()` throws `ValidationError.missingPublicAPIKey` if it is.

---

## Paywall Modes

### `.custom` — Built-in custom SwiftUI paywall

```swift
SubscriptionKitConfiguration(
    publicAPIKey: "appl_xxx",
    paywallMode: .custom
)
```

Customize copy:

```swift
let content = SubscriptionCustomPaywallContent(
    title: "Upgrade to Pro",
    subtitle: "Unlock every premium feature.",
    benefits: [
        "Unlimited access",
        "Sync across devices",
        "Cancel anytime"
    ],
    purchaseButtonTitle: "Start Now",
    restoreButtonTitle: "Restore",
    emptyOfferingTitle: "No plans found",
    emptyOfferingMessage: "Check RevenueCat offering and product setup.",
    legalLinks: [
        .init(title: "Terms", url: URL(string: "https://example.com/terms")!),
        .init(title: "Privacy", url: URL(string: "https://example.com/privacy")!)
    ]
)

SubscriptionKitConfiguration(publicAPIKey: "appl_xxx", customPaywall: content)
```

Customize theme:

```swift
let theme = SubscriptionPaywallTheme(
    accentColor: .purple,
    backgroundColor: Color(.systemBackground),
    foregroundColor: Color(.label),
    secondaryForegroundColor: Color(.secondaryLabel)
)

SubscriptionKitConfiguration(publicAPIKey: "appl_xxx", theme: theme)
```

---

### `.revenueCat` — RevenueCat hosted paywall

```swift
SubscriptionKitConfiguration(
    publicAPIKey: "appl_xxx",
    paywallMode: .revenueCat
)
```

Renders `RevenueCatUI.PaywallView`. The paywall design, copy, and packages are configured in the RevenueCat dashboard.

---

### `.scrollTemplateView(content:)` — Scroll template paywall

A rich dark-mode-first template with hero icon, coloured headline, feature list, star rating, and a sticky bottom purchase bar.

```swift
let content = SubscriptionScrollTemplatePaywallContent(
    appTitle: "My App",
    backgroundColor: Color(red: 0.04, green: 0.05, blue: 0.09),
    heroIcon: Image(systemName: "star.fill"),
    headlineSegments: [
        .init(text: "Go ", color: .white),
        .init(text: "Pro", color: .cyan)
    ],
    subtitle: "Unlock every premium feature.",
    features: [
        .init(icon: Image(systemName: "sparkles"), title: "Premium Effects", subtitle: "Advanced animations and styles."),
        .init(icon: Image(systemName: "rectangle.stack.fill"), title: "Unlimited Boards", subtitle: "Save every project and switch fast.")
    ],
    rating: .init(score: "4.9", title: "Top rated", subtitle: "By thousands of users"),
    planSectionTitle: "Choose your plan",
    planOverrides: [
        .init(packageID: "$rc_annual", title: "Yearly", badge: "Best Value")
    ],
    moreInfoRows: [
        .init(title: "Cancel anytime", subtitle: "Manage from your App Store settings."),
        .init(title: "Restore purchases", subtitle: "Works on any device with the same Apple ID.")
    ],
    purchaseButtonTitle: "Continue",
    restoreButtonTitle: "Restore",
    skipButtonTitle: "Not now",
    emptyOfferingTitle: "No plans available",
    emptyOfferingMessage: "Check RevenueCat offering configuration.",
    legalLinks: [
        .init(title: "Terms", url: URL(string: "https://example.com/terms")!),
        .init(title: "Privacy", url: URL(string: "https://example.com/privacy")!)
    ],
    palette: .init(
        accent: .cyan,
        background: Color(red: 0.04, green: 0.05, blue: 0.09),
        foreground: .white,
        secondaryForeground: .white.opacity(0.72),
        panelBackground: .white.opacity(0.12),
        planBackground: .white.opacity(0.09),
        selectedPlanBackground: .cyan.opacity(0.18),
        selectedPlanBorder: .cyan,
        bottomBarBackground: Color(red: 0.04, green: 0.05, blue: 0.09).opacity(0.96)
    )
)

SubscriptionKitConfiguration(
    publicAPIKey: "appl_xxx",
    paywallMode: .scrollTemplateView(content: content)
)
```

#### Plan Overrides

`PlanOverride` lets you customise the title, subtitle, or badge for a specific package without changing RevenueCat:

```swift
planOverrides: [
    .init(packageID: "$rc_annual", title: "Yearly — Save 40%", badge: "Best Value"),
    .init(productIdentifier: "com.yourapp.lifetime", title: "Lifetime Access", subtitle: "One-time purchase, forever.")
]
```

---

### `.custom(provider:)` — Fully custom SwiftUI paywall

Build any SwiftUI paywall you want while receiving packages, premium state, purchase, restore, and dismiss via `SubscriptionPaywallContext`.

**Step 1 — Define a provider:**

```swift
struct MyPaywallProvider: SubscriptionCustomPaywallProviding {
    let appName: String

    func makePaywall(context: SubscriptionPaywallContext) -> some View {
        MyPaywallView(appName: appName, context: context)
    }
}
```

**Step 2 — Configure the kit:**

```swift
SubscriptionKitConfiguration(
    publicAPIKey: "appl_xxx",
    paywallMode: .custom(provider: MyPaywallProvider(appName: "My App"))
)
```

**Step 3 — Build your view with `SubscriptionPaywallContext`:**

| Member | Type | Description |
|---|---|---|
| `configuration` | `SubscriptionKitConfiguration` | Full kit configuration. |
| `packages` | `[SubscriptionPackage]` | Packages from RevenueCat, sorted by `productOrder`. |
| `state` | `PremiumState` | Current subscription state. |
| `isPremium` | `Bool` | `true` when state is `.premium` or `.premiumFromSnapshot`. |
| `isPurchasing` | `Bool` | `true` while a purchase is in progress. |
| `isRestoring` | `Bool` | `true` while a restore is in progress. |
| `lastError` | `Error?` | Last purchase or restore error. |
| `purchase(_:)` | `async` method | Purchases the given package and auto-dismisses when premium is unlocked. |
| `restorePurchases()` | `async` method | Restores purchases and auto-dismisses when premium is unlocked. |
| `dismiss()` | method | Dismisses the paywall immediately. |

```swift
struct MyPaywallView: View {
    let appName: String
    @ObservedObject var context: SubscriptionPaywallContext

    var body: some View {
        VStack(spacing: 24) {
            Text(appName).font(.largeTitle.bold())

            ForEach(context.packages) { package in
                Button {
                    Task { await context.purchase(package) }
                } label: {
                    Text("\(package.title) — \(package.localizedPrice)")
                }
                .disabled(context.isPurchasing)
            }

            Button("Restore") {
                Task { await context.restorePurchases() }
            }
            .disabled(context.isRestoring)

            if let error = context.lastError {
                Text(error.localizedDescription)
                    .foregroundStyle(.red)
                    .font(.footnote)
            }

            Button("Not now") { context.dismiss() }
        }
        .padding()
    }
}
```

---

## Subscription State Reference

| State | Meaning |
|---|---|
| `.unknown` | Not loaded yet. |
| `.loading` | Fetching customer info from RevenueCat. |
| `.premium` | Active entitlement confirmed by RevenueCat. |
| `.premiumFromSnapshot` | RevenueCat unavailable; local snapshot confirms previous premium state. |
| `.nonPremium` | No active configured entitlement. |
| `.failed(String)` | Config or refresh failed with no fallback. |

`isPremium` returns `true` for both `.premium` and `.premiumFromSnapshot`.

---

## SubscriptionManager API

```swift
// Configure (call once at app launch)
try await manager.configure(config)

// Refresh customer info
await manager.refreshCustomerInfo()

// Purchase a package
await manager.purchase(package: package)

// Restore purchases
await manager.restorePurchases()

// Login after your own auth
await manager.logIn(appUserID: "user-id")

// Logout
await manager.logOut()

// Open Apple subscription management
await manager.openManageSubscriptionURL()
```

---

## Unit Testing

Inject `MockRevenueCatAdapter` (from the test target) to test your subscription logic without hitting the RevenueCat SDK:

```swift
@MainActor
final class MockRevenueCatAdapter: SubscriptionRevenueCatAdapting {
    var stubbedCustomerInfo: SubscriptionCustomerSnapshot = .init(activeEntitlementIDs: [])
    var stubbedOfferings: [SubscriptionPackage] = []
    var stubbedPurchaseOutcome: SubscriptionPurchaseOutcome = .cancelled
    var shouldThrowOnPurchase = false

    func configure(with configuration: SubscriptionKitConfiguration) throws {}
    func cachedCustomerInfo() -> SubscriptionCustomerSnapshot? { nil }
    func customerInfo() async throws -> SubscriptionCustomerSnapshot { stubbedCustomerInfo }
    func offerings(identifier: String?, placementIdentifier: String?) async throws -> [SubscriptionPackage] { stubbedOfferings }
    func customerInfoUpdates() -> AsyncStream<SubscriptionCustomerSnapshot> { .init { _ in } }
    func purchase(package: SubscriptionPackage) async throws -> SubscriptionPurchaseOutcome {
        if shouldThrowOnPurchase { throw URLError(.networkConnectionLost) }
        return stubbedPurchaseOutcome
    }
    func restorePurchases() async throws -> SubscriptionCustomerSnapshot { stubbedCustomerInfo }
    func logIn(appUserID: String) async throws -> SubscriptionCustomerSnapshot { stubbedCustomerInfo }
    func logOut() async throws -> SubscriptionCustomerSnapshot { stubbedCustomerInfo }
    func managementURL() async throws -> URL? { nil }
}

// Test
@MainActor
final class MyTests: XCTestCase {
    func test_purchase_setsPremium() async throws {
        let mock = MockRevenueCatAdapter()
        mock.stubbedPurchaseOutcome = .success(.init(activeEntitlementIDs: ["premium"]))
        let manager = SubscriptionManager(adapter: mock)

        let config = SubscriptionKitConfiguration(publicAPIKey: "appl_test")
        try await manager.configure(config)

        let package = SubscriptionPackage(id: "monthly", productIdentifier: "com.test.monthly",
            productType: .monthly, title: "Monthly", localizedDescription: "Monthly plan",
            localizedPrice: "$4.99", periodDescription: "1 month")
        await manager.purchase(package: package)
        XCTAssertTrue(manager.isPremium)
    }
}
```

---

## App Store Connect Setup

### 1. Create or verify your app

1. Open [App Store Connect](https://appstoreconnect.apple.com).
2. Go to **My Apps** and create or select your app.
3. Confirm the Bundle ID matches your Xcode target.

### 2. Enable In-App Purchase capability in Xcode

1. Open the Xcode project.
2. Select your app target.
3. Open **Signing & Capabilities**.
4. Click **+** and add **In-App Purchase**.
5. Use a real Apple Developer team and your production Bundle ID.

### 3. Create a subscription group

1. In App Store Connect, open your app.
2. Go to **Monetization → Subscriptions**.
3. Click **+** to create a new subscription group (e.g. `Premium`).
4. Add a display name localisation for the group.

> Weekly, monthly, and yearly plans should be in the same subscription group so Apple handles upgrade/downgrade/crossgrade correctly.

### 4. Create auto-renewable subscriptions

For each recurring plan, click **+** in your subscription group:

| Field | Value |
|---|---|
| Reference Name | e.g. `Monthly Premium` |
| Product ID | e.g. `com.yourcompany.yourapp.subscription.monthly` |
| Subscription Duration | Monthly / Weekly / Yearly |
| Price | Set your tier |
| Availability | All territories (or select) |
| Localisation | Display name + description |

Recommended product ID scheme:

```
com.yourcompany.yourapp.subscription.weekly
com.yourcompany.yourapp.subscription.monthly
com.yourcompany.yourapp.subscription.yearly
```

### 5. Create a lifetime non-consumable (optional)

If you sell lifetime access:

1. Go to **Monetization → In-App Purchases**.
2. Click **+** and choose **Non-Consumable**.
3. Use a product ID like `com.yourcompany.yourapp.lifetime`.
4. Set price, localisation, and availability.

If you do not sell lifetime access, remove `.lifetime` from `productOrder`.

### 6. Agreements, Tax, and Banking

Paid IAP requires completed Apple agreements. Go to **Business → Agreements, Tax, and Banking** and complete all required documents before testing purchases.

### 7. Sandbox testing

- Create sandbox tester accounts in **Users and Access → Sandbox → Testers**.
- On a real device, sign out of the App Store, then use the sandbox account when prompted during a test purchase.
- Product IDs must match App Store Connect exactly.
- The bundle ID on the device must match the app in App Store Connect.

---

## RevenueCat Setup

### 1. Create a project and iOS app

1. Open [RevenueCat dashboard](https://app.revenuecat.com).
2. Create a new project or open an existing one.
3. Go to **Project Settings → Apps** and click **+** to add an iOS app.
4. Enter:
   - App name
   - Bundle ID (must match Xcode and App Store Connect exactly)

### 2. Connect Apple credentials

RevenueCat needs Apple credentials to validate receipts:

| Credential | Where to get it | Required for |
|---|---|---|
| App Store Connect API Key | App Store Connect → Users → API Keys (Team key) | Subscription status, receipt validation |
| In-App Purchase Key | App Store Connect → Business → In-App Purchase Key | StoreKit 2 transaction signing |

Set both in RevenueCat: **Project Settings → Apps → [Your iOS App] → App Store Connect API**.

### 3. Get your public API key

1. In RevenueCat, open **Project Settings → API Keys**.
2. Copy the **iOS public SDK key** (starts with `appl_`).
3. Paste it into `SubscriptionKitConfiguration(publicAPIKey: "appl_xxx")`.

> Use the **iOS platform public key** for Apple sandbox, TestFlight, App Review, and production.  
> Use the **Test Store key** only for RevenueCat Test Store (simulated purchases, no real Apple backend).  
> **Never ship a Test Store key** in production.

### 4. Add products in RevenueCat

1. Go to **Product Catalog → Products**.
2. Click **+** for each App Store product:
   - Enter the exact product ID from App Store Connect.
   - Select the store (Apple App Store).

| RevenueCat product | App Store product ID |
|---|---|
| Weekly | `com.yourcompany.yourapp.subscription.weekly` |
| Monthly | `com.yourcompany.yourapp.subscription.monthly` |
| Yearly | `com.yourcompany.yourapp.subscription.yearly` |
| Lifetime | `com.yourcompany.yourapp.lifetime` |

### 5. Create an entitlement

1. Go to **Product Catalog → Entitlements**.
2. Click **+** and create an entitlement named `premium`.
3. Attach all products that should unlock premium access to this entitlement.

This identifier must match `entitlementID` in your `SubscriptionKitConfiguration`:

```swift
SubscriptionKitConfiguration(entitlementID: "premium")
```

### 6. Create an offering and packages

1. Go to **Product Catalog → Offerings**.
2. Click **+** and create an offering (e.g. `default`).
3. Inside the offering, click **+ Package** for each plan:

| Package identifier | Maps to product |
|---|---|
| `$rc_weekly` | Weekly subscription |
| `$rc_monthly` | Monthly subscription |
| `$rc_annual` | Yearly subscription |
| `$rc_lifetime` | Lifetime non-consumable |

4. Configure your app to use this offering:

```swift
SubscriptionKitConfiguration(
    publicAPIKey: "appl_xxx",
    offeringIdentifier: "default"
)
```

### 7. Configure RevenueCat hosted paywall (optional)

Only required when `paywallMode == .revenueCat`.

1. Go to **Paywalls** in the RevenueCat dashboard.
2. Click **+** to create a new paywall.
3. Assign it to your offering or placement.
4. Add packages and customize the design.
5. Publish the paywall.

---

## Local StoreKit Testing

For fast simulator testing without App Store Connect:

1. In Xcode, go to **File → New → File → StoreKit Configuration File**.
2. Add your products (matching the same product IDs you plan to use in production).
3. Open your scheme editor (**Product → Scheme → Edit Scheme…**).
4. Select **Run → Options**.
5. Set **StoreKit Configuration** to your `.storekit` file.
6. Run on the simulator.

> Local StoreKit testing simulates purchase dialogs but does not contact RevenueCat. For end-to-end RevenueCat testing, use the RevenueCat Test Store API key with Test Store products, or use the real iOS platform key with Apple sandbox.

---

## Testing Strategy

### Run unit tests

```bash
# Run tests (requires macOS with Swift toolchain)
swift test --package-path /path/to/SubscriptionKit

# Or via Xcode
xcodebuild test \
  -scheme SubscriptionKit \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

The test suite covers:

- `SubscriptionKitConfiguration` validation and defaults
- `SubscriptionManager` state transitions using `MockRevenueCatAdapter`
- Package ordering by `productOrder`
- Premium snapshot persistence and fallback
- Purchase, restore, logIn, and logOut behavior

### Manual QA checklist

1. Launch app with `debugLoggingEnabled: true`.
2. Confirm subscription state shows correctly.
3. Tap **Show Paywall** — packages should appear.
4. Make a sandbox purchase — state should become premium and paywall should dismiss.
5. Cancel a purchase — state should remain non-premium.
6. Tap **Restore Purchases** — should restore premium if a previous sandbox purchase exists.
7. Kill network connection — confirm `premiumFromSnapshot` state after restart.
8. Tap **Manage Subscription** — should open Apple subscription management.
9. Test `logIn` / `logOut` with your own user authentication if applicable.

---

## Common Problems

### `RevenueCat public API key is missing`

**Cause**: `publicAPIKey` is empty or whitespace.  
**Fix**: Set a valid RevenueCat iOS public SDK key.

### No packages appear in the paywall

**Checklist**:
- [ ] Product IDs match App Store Connect exactly (case-sensitive).
- [ ] Products are added to RevenueCat product catalog.
- [ ] Products are attached to the entitlement.
- [ ] Products are attached to the offering.
- [ ] `offeringIdentifier` matches the RevenueCat offering ID (or is `nil` for current offering).
- [ ] You are not mixing a Test Store API key with real App Store products (or vice versa).
- [ ] Agreements, Tax, and Banking are complete in App Store Connect.

### User purchased but premium is still inactive

**Fix**: Confirm the RevenueCat entitlement ID is exactly `"premium"` (or update `entitlementID`), and that the purchased product is attached to the entitlement.

### `Manage Subscription` does nothing

**Fix**: Refresh customer info after a purchase or restore. Management URL is only available after RevenueCat returns it. Test with a real sandbox purchase.

### RevenueCat logs are too noisy

```swift
SubscriptionKitConfiguration(publicAPIKey: "appl_xxx", debugLoggingEnabled: false)
```

---

## Release Checklist

Before submitting to App Review:

- [ ] Replace the development API key with the RevenueCat iOS public SDK key.
- [ ] Do not ship a RevenueCat Test Store API key.
- [ ] Set `debugLoggingEnabled` to `false`.
- [ ] Confirm App Store Connect subscription group, durations, prices, and localisations are complete.
- [ ] Confirm the lifetime non-consumable product is set up if used.
- [ ] Confirm RevenueCat product IDs match App Store Connect exactly.
- [ ] Confirm RevenueCat entitlement ID matches `entitlementID` in the configuration.
- [ ] Confirm all packages in the offering are attached to the entitlement.
- [ ] If using `.revenueCat` mode, confirm the hosted paywall is configured and published.
- [ ] Test fresh install, purchase, cancel, restore, and subscription management on a real device with a sandbox account.
- [ ] Verify legal links point to your production Terms and Privacy URLs.
- [ ] Run the full unit test suite and confirm all tests pass.

---

## Versioning

SubscriptionKit follows [Semantic Versioning](https://semver.org):

- **MAJOR** — breaking API changes.
- **MINOR** — new features, backwards compatible.
- **PATCH** — bug fixes, backwards compatible.

See [CHANGELOG.md](CHANGELOG.md) for the full release history.

### Creating a new release (GitHub)

1. Update `CHANGELOG.md` with the new version and date.
2. Commit the changes: `git commit -am "Release 1.x.x"`.
3. Tag the release: `git tag -a 1.x.x -m "Version 1.x.x"`.
4. Push tag: `git push origin 1.x.x`.
5. Create a GitHub Release from the tag with release notes.

SPM consumers using `.upToNextMajor(from: "1.0.0")` will pick up patch and minor releases automatically.

---

## Useful Official Docs

- [RevenueCat SDK Quickstart](https://www.revenuecat.com/docs/getting-started/quickstart)
- [RevenueCat configuring SDK](https://www.revenuecat.com/docs/getting-started/configuring-sdk)
- [RevenueCat iOS product setup](https://www.revenuecat.com/docs/getting-started/entitlements/ios-products)
- [RevenueCat App Store Connect API key configuration](https://www.revenuecat.com/docs/service-credentials/itunesconnect-app-specific-shared-secret/app-store-connect-api-key-configuration)
- [RevenueCat In-App Purchase key configuration](https://www.revenuecat.com/docs/service-credentials/itunesconnect-app-specific-shared-secret/in-app-purchase-key-configuration)
- [Apple: Offer auto-renewable subscriptions](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions/)
- [Apple: In-App Purchase information reference](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information/)
- [Apple: Testing in-app purchases](https://developer.apple.com/documentation/storekit/testing-in-app-purchases-with-sandbox)
- [Swift Package Manager documentation](https://www.swift.org/documentation/package-manager/)
