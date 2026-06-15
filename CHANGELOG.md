# Changelog

All notable changes to SubscriptionKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-06-15

### Added
- `SubscriptionManager` — main observable subscription state manager.
- `SubscriptionKitConfiguration` — full configuration struct for API key, entitlement, paywall mode, theme, and more.
- `SubscriptionPaywallView` — SwiftUI view supporting four paywall modes.
- `ScrollTemplateSubscriptionPaywallView` — built-in scroll-based paywall template with hero icon, feature list, rating block, and plan selector.
- `SubscriptionCustomPaywallProviding` protocol — build fully custom SwiftUI paywalls while receiving purchase/restore context via `SubscriptionPaywallContext`.
- `AnySubscriptionCustomPaywallProvider` — type-eraser for custom paywall providers.
- `SubscriptionRevenueCatAdapting` protocol — testable adapter interface for RevenueCat.
- `RevenueCatSubscriptionAdapter` — concrete RevenueCat SDK integration.
- `PremiumState` enum — subscription state including snapshot fallback support.
- `SubscriptionProductType` — lifetime, yearly, monthly, weekly, custom.
- `SubscriptionPackage` — RevenueCat package wrapped in a framework-agnostic model.
- `SubscriptionPremiumSnapshot` — `UserDefaults`-backed premium state cache for offline resilience.
- `SubscriptionPaywallTheme` — accent, background, foreground, and secondary colors for the built-in custom paywall.
- `SubscriptionScrollTemplatePaywallContent` — rich content model with palette, headline segments, features, rating, plan overrides, and more.
- Full unit test suite covering configuration validation, state transitions, package ordering, snapshot fallback, purchase, and restore.
- README with App Store Connect setup, RevenueCat setup, paywall mode guide, and release checklist.
