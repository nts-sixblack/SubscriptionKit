/// SubscriptionKit
///
/// A lightweight Swift package that wraps RevenueCat into a clean,
/// testable subscription layer for iOS apps.
///
/// ## Quick Start
///
/// ```swift
/// // 1. Configure once at app launch
/// let config = SubscriptionKitConfiguration(
///     publicAPIKey: "appl_your_revenuecat_ios_key",
///     entitlementID: "premium",
///     paywallMode: .custom
/// )
///
/// @StateObject private var subscriptionManager = SubscriptionManager.shared
///
/// .task {
///     try? await subscriptionManager.configure(config)
/// }
///
/// // 2. Gate premium features
/// if subscriptionManager.isPremium {
///     PremiumFeatureView()
/// }
///
/// // 3. Present paywall
/// .sheet(isPresented: $showPaywall) {
///     SubscriptionPaywallView(manager: subscriptionManager, configuration: config)
/// }
/// ```
@_exported import Foundation
