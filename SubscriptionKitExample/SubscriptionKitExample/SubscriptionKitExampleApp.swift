//
//  SubscriptionKitExampleApp.swift
//  SubscriptionKitExample
//
//  Created by SixBlack on 13/6/26.
//

import SubscriptionKit
import SwiftUI

@main
struct SubscriptionKitExampleApp: App {
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    private let subscriptionConfiguration = SubscriptionKitConfiguration(
        publicAPIKey: "appl_LvbEgoxTobVLwlXVUwdUkTRnHoU",
        entitlementID: "SixPilot/LedBoard Pro",
        paywallMode: .custom(provider: LedBoardProPaywallProvider()),
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
