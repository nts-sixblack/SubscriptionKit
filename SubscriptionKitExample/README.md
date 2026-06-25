# SubscriptionKitExample

Example SwiftUI app demonstrating a reusable subscription flow built on top of RevenueCat, RevenueCatUI, and StoreKit.

This project includes:

- RevenueCat SDK setup through `SubscriptionManager`.
- Two paywall modes: custom SwiftUI paywall and RevenueCat hosted paywall.
- Subscription state tracking with local premium snapshot fallback.
- Purchase, restore, login, logout, refresh, and manage subscription actions.
- Local StoreKit configuration for development testing.

## Requirements

- Xcode 16 or later.
- iOS 18 SDK target in this example project.
- Apple Developer account with In-App Purchase capability enabled for production or sandbox testing.
- RevenueCat project configured with iOS app, products, entitlement, and offering.

The project already includes the RevenueCat Swift Package dependency:

- `RevenueCat`
- `RevenueCatUI`
- `ReceiptParser`

Dependency source: `https://github.com/RevenueCat/purchases-ios-spm.git`

## Project Structure

```text
SubscriptionKitExample/
├── ContentView.swift
├── StoreKitConfig.storekit
├── SubscriptionKitExampleApp.swift
└── SubscriptionKit/
    ├── SubscriptionKitConfig.swift
    ├── SubscriptionManager.swift
    ├── SubscriptionModels.swift
    ├── SubscriptionPaywallView.swift
    └── SubscriptionRevenueCatAdapter.swift
```

Important files:

| File | Purpose |
| --- | --- |
| `SubscriptionKitExampleApp.swift` | Creates `SubscriptionKitConfiguration` and configures `SubscriptionManager.shared` on app launch. |
| `SubscriptionKitConfig.swift` | Defines every configurable option for the subscription flow and custom paywall. |
| `SubscriptionManager.swift` | Main observable subscription state manager used by SwiftUI. |
| `SubscriptionRevenueCatAdapter.swift` | Bridges this kit to RevenueCat SDK APIs. |
| `SubscriptionPaywallView.swift` | Shows the paywall selected by `PaywallMode`: RevenueCat hosted, built-in custom SwiftUI, scroll template, or a user-supplied custom provider. |
| `StoreKitConfig.storekit` | Local StoreKit products for simulator/local purchase testing. |

## Quick Start

1. Open `SubscriptionKitExample.xcodeproj` in Xcode.
2. Select the `SubscriptionKitExample` scheme.
3. Open `SubscriptionKitExample/SubscriptionKitExampleApp.swift`.
4. Replace the empty `publicAPIKey` with your RevenueCat iOS public API key.
5. Make sure `entitlementID`, product IDs, and offering configuration match RevenueCat.
6. Run the app.

Current app entry point:

```swift
@main
struct SubscriptionKitExampleApp: App {
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    private let subscriptionConfiguration = SubscriptionKitConfiguration(
        publicAPIKey: "",
        paywallMode: .custom,
        debugLoggingEnabled: true
    )

    var body: some Scene {
        WindowGroup {
            ContentView(
                subscriptionManager: subscriptionManager,
                subscriptionConfiguration: subscriptionConfiguration
            )
            .task {
                try? await subscriptionManager.configure(subscriptionConfiguration)
            }
        }
    }
}
```

Production example:

```swift
private let subscriptionConfiguration = SubscriptionKitConfiguration(
    publicAPIKey: "appl_your_revenuecat_ios_public_api_key",
    entitlementID: "premium",
    paywallMode: .custom,
    offeringIdentifier: "default",
    productOrder: [.yearly, .monthly, .weekly, .lifetime],
    debugLoggingEnabled: false
)
```

## Configuration Reference

All configuration lives in `SubscriptionKitConfiguration`.

| Config | Type | Default | Description |
| --- | --- | --- | --- |
| `publicAPIKey` | `String` | Required | RevenueCat public SDK API key. This cannot be empty. Use a Test Store key only for development, and use the platform-specific iOS key for production. |
| `entitlementID` | `String` | `"premium"` | RevenueCat entitlement identifier used to decide whether the user is premium. The app checks `customerInfo.entitlements.active.keys` for this value. |
| `appUserID` | `String?` | `nil` | Optional stable user ID passed to RevenueCat during SDK configuration. Use this when your app has authenticated users. If nil, RevenueCat uses an anonymous app user ID. |
| `paywallMode` | `PaywallMode` | `.custom` | Selects the paywall implementation. Use `.custom` for the built-in SwiftUI paywall, `.revenueCat` for RevenueCatUI hosted paywall, `.scrollTemplateView(content:)` for the scroll template, or `.custom(provider:)` to supply your own `SubscriptionCustomPaywallProviding`. |
| `offeringIdentifier` | `String?` | `nil` | Optional RevenueCat offering ID. If provided, packages are loaded from `offerings.offering(identifier:)`. |
| `placementIdentifier` | `String?` | `nil` | Optional RevenueCat targeting placement ID. Used only when `offeringIdentifier` is nil. |
| `productOrder` | `[SubscriptionProductType]` | `[.lifetime, .yearly, .monthly, .weekly]` | Sort order for packages in the custom paywall. Unknown/custom package types are sorted after configured types. |
| `defaultSelectedProduct` | `SubscriptionProductType?` | `nil` | Product type pre-selected when the paywall opens. Matched against displayed packages. Falls back to the first displayed package when `nil` or when no match is found. |
| `customPaywall` | `SubscriptionCustomPaywallContent` | `.default` | Text, benefits, button labels, empty state copy, and legal links for the custom paywall. |
| `showsCloseButton` | `Bool` | `true` | Shows a close button in the custom paywall and passes `displayCloseButton` to RevenueCat hosted paywall. |
| `showsRestoreButton` | `Bool` | `true` | Shows the restore button in the custom SwiftUI paywall. |
| `theme` | `SubscriptionPaywallTheme` | `.default` | Colors used by the custom SwiftUI paywall. |
| `debugLoggingEnabled` | `Bool` | `false` | Enables RevenueCat debug logging by setting `Purchases.logLevel = .debug`. Keep this off in production builds. |
| `snapshotStorageKey` | `String` | `"SubscriptionKit.PremiumSnapshot"` | UserDefaults key used to cache the last known premium state for offline/fallback display. |

Validation:

- `publicAPIKey` is required.
- Empty or whitespace-only API key throws `SubscriptionKitConfiguration.ValidationError.missingPublicAPIKey`.

## Paywall Modes

### Custom SwiftUI Paywall

Use this mode when you want full control over layout and text:

```swift
SubscriptionKitConfiguration(
    publicAPIKey: "appl_xxx",
    paywallMode: .custom
)
```

The custom paywall:

- Loads RevenueCat packages through `SubscriptionManager.packages`.
- Shows packages sorted by `productOrder`.
- Purchases the selected package with `manager.purchase(package:)`.
- Restores purchases with `manager.restorePurchases()`.
- Dismisses itself after premium becomes active.
- Uses `SubscriptionCustomPaywallContent` and `SubscriptionPaywallTheme`.

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

let configuration = SubscriptionKitConfiguration(
    publicAPIKey: "appl_xxx",
    customPaywall: content
)
```

Customize theme:

```swift
let theme = SubscriptionPaywallTheme(
    accentColor: .purple,
    backgroundColor: Color(.systemBackground),
    foregroundColor: Color(.label),
    secondaryForegroundColor: Color(.secondaryLabel)
)

let configuration = SubscriptionKitConfiguration(
    publicAPIKey: "appl_xxx",
    theme: theme
)
```

### RevenueCat Hosted Paywall

Use this mode when you want RevenueCatUI to render the paywall configured in the RevenueCat dashboard:

```swift
SubscriptionKitConfiguration(
    publicAPIKey: "appl_xxx",
    paywallMode: .revenueCat
)
```

The hosted paywall uses `RevenueCatUI.PaywallView`.

On purchase or restore completion, the app refreshes customer info and dismisses the paywall.

RevenueCat hosted paywall design, packages, and experiments must be configured in the RevenueCat dashboard.

### Custom Provider Paywall

Use this mode when you want a fully custom SwiftUI paywall that carries its own model, dependencies, and helper logic, while still receiving packages, state, purchase, restore, and dismiss behaviour through a standard context object.

**Step 1 — define a provider:**

```swift
struct MyPaywall: SubscriptionCustomPaywallProviding {
    let title: String

    func makePaywall(context: SubscriptionPaywallContext) -> some View {
        MyPaywallView(title: title, context: context)
    }
}
```

**Step 2 — configure the kit:**

```swift
let config = SubscriptionKitConfiguration(
    publicAPIKey: "appl_xxx",
    paywallMode: .custom(provider: MyPaywall(title: "Go Pro"))
)
```

**Step 3 — use `SubscriptionPaywallContext` in your view:**

`SubscriptionPaywallContext` is an `ObservableObject` passed into `makePaywall`. It exposes:

| Member | Type | Description |
| --- | --- | --- |
| `configuration` | `SubscriptionKitConfiguration` | Full kit configuration. |
| `packages` | `[SubscriptionPackage]` | Packages loaded from RevenueCat, sorted by `productOrder`. |
| `state` | `PremiumState` | Current premium state from `SubscriptionManager`. |
| `isPremium` | `Bool` | `true` when state is `.premium` or `.premiumFromSnapshot`. |
| `isPurchasing` | `Bool` | `true` while a purchase is in progress. |
| `isRestoring` | `Bool` | `true` while a restore is in progress. |
| `lastError` | `Error?` | Last purchase or restore error, if any. |
| `selectedPackage` | `SubscriptionPackage?` | Package pre-selected per `defaultSelectedProduct`, or the first displayed package when unset. |
| `selectPackage(_:)` | Method | Updates the selected package in custom provider paywalls. |
| `purchase(_:) async` | Method | Purchases the given package and auto-dismisses when premium is unlocked. |
| `restorePurchases() async` | Method | Restores purchases and auto-dismisses when premium is unlocked. |
| `dismiss()` | Method | Dismisses the paywall immediately. |

Example view:

```swift
struct MyPaywallView: View {
    let title: String
    @ObservedObject var context: SubscriptionPaywallContext

    var body: some View {
        VStack(spacing: 24) {
            Text(title).font(.largeTitle.bold())

            ForEach(context.packages) { package in
                Button(package.localizedPrice) {
                    Task { await context.purchase(package) }
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

The provider conforms to `SubscriptionCustomPaywallProviding`, which is annotated `@MainActor` and uses an associated `Body: View`, so the conforming type can be a lightweight struct with no `@State` itself. The kit wraps it in `AnySubscriptionCustomPaywallProvider` internally so `PaywallMode` stays non-generic.

## Product Types

`SubscriptionProductType` supports:

| Case | RevenueCat package type mapping |
| --- | --- |
| `.lifetime` | `.lifetime` |
| `.yearly` | `.annual` |
| `.monthly` | `.monthly` |
| `.weekly` | `.weekly` |
| `.custom` | `.custom` |
| `.unknown` | Any unsupported package type |

The local StoreKit file currently defines:

| Product ID | Type | Reference name |
| --- | --- | --- |
| `com.sixpilot.subscription.lifetime` | Non-consumable | Lifetime |
| `com.sixpilot.subscription.weekly` | Auto-renewable subscription | Weekly |
| `com.sixpilot.subscription.monthly` | Auto-renewable subscription | Monthly |
| `com.sixpilot.subscription.yearly` | Auto-renewable subscription | Yearly |

For production, these product IDs must exist in App Store Connect and RevenueCat if you keep the sample identifiers. In a real app, replace them with your own bundle/product naming convention.

## Usage in SwiftUI

Use the shared manager:

```swift
@StateObject private var subscriptionManager = SubscriptionManager.shared
```

Configure once near app startup:

```swift
.task {
    try? await subscriptionManager.configure(subscriptionConfiguration)
}
```

Read premium state:

```swift
if subscriptionManager.isPremium {
    PremiumFeatureView()
} else {
    LockedFeatureView()
}
```

Show paywall:

```swift
.sheet(isPresented: $isShowingPaywall) {
    // Can be initialized without arguments, or with a custom onDismiss callback:
    SubscriptionPaywallView {
        print("Paywall dismissed")
    }
}
```

Refresh customer info:

```swift
Task {
    await subscriptionManager.refreshCustomerInfo()
}
```

Restore purchases:

```swift
Task {
    await subscriptionManager.restorePurchases()
}
```

Open Apple subscription management:

```swift
Task {
    await subscriptionManager.openManageSubscriptionURL()
}
```

Login after your own app authentication:

```swift
Task {
    await subscriptionManager.logIn(appUserID: user.id)
}
```

Logout:

```swift
Task {
    await subscriptionManager.logOut()
}
```

## Subscription State

`SubscriptionManager.state` can be:

| State | Meaning |
| --- | --- |
| `.unknown` | Manager has not loaded a reliable subscription state yet. |
| `.loading` | Customer info is being fetched. |
| `.premium` | RevenueCat returned an active entitlement matching `entitlementID`. |
| `.premiumFromSnapshot` | RevenueCat state was unavailable, but local snapshot says the user was premium previously. |
| `.nonPremium` | No active configured entitlement. |
| `.failed(String)` | Configuration or refresh failed and no fallback could be applied. |

`isPremium` returns true for both `.premium` and `.premiumFromSnapshot`.

The snapshot fallback is intentionally conservative for UX continuity, but RevenueCat remains the source of truth for purchases and entitlement updates.

## Configure App Store Connect

Use App Store Connect for the real store products users buy in production and Apple sandbox.

### 1. Create or Verify the App

1. Go to App Store Connect.
2. Open `My Apps`.
3. Create or select your app.
4. Confirm the Bundle ID matches the Xcode target.

Current example bundle ID:

```text
nts.sixblack.SubscriptionKitExample
```

For your own app, update the bundle identifier in Xcode and use the same value in App Store Connect and RevenueCat.

### 2. Enable In-App Purchase Capability

1. Open the Xcode project.
2. Select the app target.
3. Open `Signing & Capabilities`.
4. Add `In-App Purchase`.
5. Use a real team and bundle identifier for device/sandbox testing.

### 3. Create Subscription Group

1. In App Store Connect, open your app.
2. Go to `Monetization` > `Subscriptions`.
3. Create a subscription group, for example `Premium`.
4. Add localization for the subscription group display name.

Weekly, monthly, and yearly plans should usually be in the same subscription group so Apple can handle upgrade, downgrade, and crossgrade behavior correctly.

### 4. Create Auto-Renewable Subscriptions

Create products that match the product IDs you will configure in RevenueCat:

```text
com.yourcompany.yourapp.subscription.weekly
com.yourcompany.yourapp.subscription.monthly
com.yourcompany.yourapp.subscription.yearly
```

For each subscription:

1. Enter reference name.
2. Enter product ID.
3. Select subscription duration.
4. Set price.
5. Configure availability.
6. Add localization display name and description.
7. Add review screenshot and notes if required.
8. Save.

Apple product IDs can contain letters, numbers, hyphens, periods, and underscores, and should be stable once used.

### 5. Configure Lifetime Purchase

The sample lifetime product is modeled as a non-consumable:

```text
com.sixpilot.subscription.lifetime
```

For your app:

1. Go to `Monetization` > `In-App Purchases`.
2. Create a non-consumable product.
3. Use a product ID like:

```text
com.yourcompany.yourapp.lifetime
```

4. Set price, availability, localization, review screenshot, and notes.

If you do not sell lifetime access, remove `.lifetime` from `productOrder` and do not add a lifetime package to RevenueCat offerings.

### 6. Agreements, Tax, and Banking

Paid in-app purchases require valid Apple agreements, tax, and banking setup. If products do not load in sandbox or production, check this before debugging code.

### 7. Sandbox Testing

Use Apple sandbox accounts or StoreKit local testing. Make sure:

- Product IDs match App Store Connect exactly.
- Products are cleared for sale or available for testing.
- Bundle ID matches the app in App Store Connect.
- The RevenueCat app is connected to the same bundle ID.

## Configure RevenueCat

RevenueCat must know about your app, products, entitlements, and offerings before this example can load packages.

### 1. Create Project and iOS App

1. Create or open a RevenueCat project.
2. Add an iOS app.
3. Enter the same Bundle ID used in Xcode/App Store Connect.
4. Connect the app to Apple App Store credentials.

RevenueCat's setup flow may ask for:

- App name.
- Bundle ID.
- App Store shared secret.
- In-App Purchase Key.
- App Store Connect API key.

For modern StoreKit 2 flows, configure the In-App Purchase Key in RevenueCat so transactions can be processed correctly.

### 2. Get API Key

In RevenueCat:

1. Open `Project Settings`.
2. Open `API keys`.
3. Copy the iOS public SDK API key.
4. Put it into `publicAPIKey`.

Use:

- Test Store API key for RevenueCat Test Store development only.
- iOS platform public API key for Apple sandbox, TestFlight, App Review, and production.

Do not ship a Test Store API key.

### 3. Configure Products

In RevenueCat product catalog, create products with the exact same product IDs from App Store Connect.

Recommended mapping:

| RevenueCat product | Store product ID | Store type |
| --- | --- | --- |
| Weekly | `com.yourcompany.yourapp.subscription.weekly` | Auto-renewable subscription |
| Monthly | `com.yourcompany.yourapp.subscription.monthly` | Auto-renewable subscription |
| Yearly | `com.yourcompany.yourapp.subscription.yearly` | Auto-renewable subscription |
| Lifetime | `com.yourcompany.yourapp.lifetime` | Non-consumable |

If you keep the sample IDs, configure these exact IDs:

```text
com.sixpilot.subscription.weekly
com.sixpilot.subscription.monthly
com.sixpilot.subscription.yearly
com.sixpilot.subscription.lifetime
```

### 4. Configure Entitlement

Create an entitlement:

```text
premium
```

This must match:

```swift
SubscriptionKitConfiguration(entitlementID: "premium")
```

Attach every product/package that should unlock premium access to this entitlement.

If you rename the entitlement in RevenueCat, update `entitlementID` in the app.

### 5. Configure Offering and Packages

Create an offering, for example:

```text
default
```

Add packages:

| Package | Product |
| --- | --- |
| Weekly | Weekly subscription product |
| Monthly | Monthly subscription product |
| Annual | Yearly subscription product |
| Lifetime | Lifetime non-consumable product |

Then configure the app:

```swift
SubscriptionKitConfiguration(
    publicAPIKey: "appl_xxx",
    offeringIdentifier: "default"
)
```

If `offeringIdentifier` is nil, this example uses RevenueCat's current offering:

```swift
offerings.current
```

If `placementIdentifier` is provided and `offeringIdentifier` is nil, this example uses:

```swift
offerings.currentOffering(forPlacement: placementIdentifier)
```

### 6. Configure RevenueCat Hosted Paywall

Only required when `paywallMode == .revenueCat`.

1. In RevenueCat, open Paywalls.
2. Create or edit a paywall.
3. Assign it to the offering/placement you use.
4. Add products/packages.
5. Publish the paywall.
6. Set:

```swift
SubscriptionKitConfiguration(
    publicAPIKey: "appl_xxx",
    paywallMode: .revenueCat
)
```

If the hosted paywall appears empty or wrong, verify the RevenueCat dashboard paywall and offering assignment first.

## Local StoreKit Testing

This project includes:

```text
SubscriptionKitExample/StoreKitConfig.storekit
```

The shared scheme already references this StoreKit configuration file.

Use local StoreKit testing when you want fast purchase UI testing without App Store Connect or RevenueCat real-store setup.

Steps:

1. Open the scheme editor in Xcode.
2. Select `Run`.
3. Open `Options`.
4. Confirm `StoreKit Configuration` points to `StoreKitConfig.storekit`.
5. Run on simulator.

Important:

- Local StoreKit products are useful for testing StoreKit purchase dialogs.
- RevenueCat offerings still come from RevenueCat unless you use RevenueCat Test Store products and API key.
- For end-to-end RevenueCat testing, configure products and offerings in RevenueCat and use the correct API key.

## Testing Strategy

Run unit tests:

```bash
xcodebuild test -project SubscriptionKitExample.xcodeproj -scheme SubscriptionKitExample -destination 'platform=iOS Simulator,name=iPhone 16'
```

Existing tests cover:

- Configuration validation and defaults.
- Default package selection via `resolvedDefaultPackage(from:)`.
- Subscription manager state transitions.
- Package ordering.
- Premium snapshot fallback.
- Purchase and restore behavior through a mock adapter.

For manual QA:

1. Launch app with debug logging enabled.
2. Tap `Refresh Customer Info`.
3. Tap `Show Paywall`.
4. Confirm packages appear.
5. Purchase each package in sandbox/local test.
6. Cancel purchase and confirm no premium unlock.
7. Restore purchases.
8. Tap `Manage Subscription`.
9. Kill network and confirm snapshot fallback behavior.

## Common Problems

### RevenueCat public API key is missing

Cause:

- `publicAPIKey` is empty.

Fix:

- Add your RevenueCat iOS public API key in `SubscriptionKitExampleApp.swift`.

### No products available

Cause:

- RevenueCat did not return packages for the selected offering.

Check:

- Product IDs match App Store Connect exactly.
- Products are added to RevenueCat product catalog.
- Products are attached to the entitlement.
- Products are attached to the offering.
- `offeringIdentifier` matches RevenueCat offering ID.
- Current offering is configured if `offeringIdentifier` is nil.
- You are not using a Test Store API key with real App Store products, or a real iOS key with Test Store-only products.

### User purchased but premium is still inactive

Cause:

- Active entitlement does not match `entitlementID`.

Fix:

- Confirm RevenueCat entitlement ID is exactly `premium`, or update the app config.
- Confirm the purchased product is attached to that entitlement.

### Manage Subscription does not open

Cause:

- RevenueCat customer info does not include a management URL yet.

Fix:

- Refresh customer info after purchase or restore.
- Test with a real Apple sandbox/TestFlight purchase when validating Apple's manage subscription URL.

### StoreKit sandbox products do not load

Check:

- Bundle ID matches App Store Connect.
- In-App Purchase capability is enabled.
- Agreements, tax, and banking are complete.
- Products are available for sale/testing.
- Product IDs in App Store Connect, RevenueCat, and code match exactly.

### RevenueCat logs are too noisy

Cause:

- `debugLoggingEnabled` is true.

Fix:

```swift
SubscriptionKitConfiguration(
    publicAPIKey: "appl_xxx",
    debugLoggingEnabled: false
)
```

## Release Checklist

Before submitting to App Review:

- Replace sample bundle ID with your production bundle ID.
- Replace empty/sample API key with RevenueCat iOS public SDK key.
- Do not ship a RevenueCat Test Store API key.
- Set `debugLoggingEnabled` to false.
- Confirm App Store Connect products are complete and submitted as needed.
- Confirm subscription group, durations, prices, availability, and localizations.
- Confirm lifetime product if used.
- Confirm RevenueCat products match App Store Connect product IDs.
- Confirm RevenueCat entitlement ID matches `entitlementID`.
- Confirm all RevenueCat offering packages are attached to the entitlement.
- Confirm hosted paywall setup if using `.revenueCat`.
- Test fresh install, purchase, cancel, restore, logout/login, and subscription management.
- Verify legal links point to your production Terms and Privacy pages.

## Useful Official Docs

- [RevenueCat SDK Quickstart](https://www.revenuecat.com/docs/getting-started/quickstart)
- [RevenueCat configuring SDK](https://www.revenuecat.com/docs/getting-started/configuring-sdk)
- [RevenueCat iOS product setup](https://www.revenuecat.com/docs/getting-started/entitlements/ios-products)
- [RevenueCat App Store Connect API key configuration](https://www.revenuecat.com/docs/service-credentials/itunesconnect-app-specific-shared-secret/app-store-connect-api-key-configuration)
- [RevenueCat In-App Purchase key configuration](https://www.revenuecat.com/docs/service-credentials/itunesconnect-app-specific-shared-secret/in-app-purchase-key-configuration)
- [Apple App Store Connect subscriptions](https://developer.apple.com/help/app-store-connect/manage-subscriptions/offer-auto-renewable-subscriptions/)
- [Apple In-App Purchase product ID reference](https://developer.apple.com/help/app-store-connect/reference/in-app-purchases-and-subscriptions/in-app-purchase-information/)
