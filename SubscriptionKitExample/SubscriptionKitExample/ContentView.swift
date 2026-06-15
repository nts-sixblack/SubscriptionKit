//
//  ContentView.swift
//  SubscriptionKitExample
//
//  Created by SixBlack on 13/6/26.
//

import SubscriptionKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var subscriptionManager: SubscriptionManager
    let subscriptionConfiguration: SubscriptionKitConfiguration
    @State private var isShowingPaywall = false

    var body: some View {
        NavigationStack {
            List {
                Section("Status") {
                    LabeledContent("Premium", value: subscriptionManager.isPremium ? "Active" : "Inactive")
                    LabeledContent("State", value: stateDescription)
                    if let error = subscriptionManager.lastError {
                        Text(error.localizedDescription)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Section("Actions") {
                    Button("Refresh Customer Info", systemImage: "arrow.clockwise") {
                        Task { await subscriptionManager.refreshCustomerInfo() }
                    }

                    Button("Show Paywall", systemImage: "crown") {
                        isShowingPaywall = true
                    }

                    Button("Restore Purchases", systemImage: "arrow.triangle.2.circlepath") {
                        Task { await subscriptionManager.restorePurchases() }
                    }

                    Button("Manage Subscription", systemImage: "person.crop.circle.badge.checkmark") {
                        Task { await subscriptionManager.openManageSubscriptionURL() }
                    }
                }

                Section("Paywall Mode") {
                    Text(paywallModeDescription)
                }
            }
            .navigationTitle("SubscriptionKit")
            .sheet(isPresented: $isShowingPaywall) {
                SubscriptionPaywallView(
                    manager: subscriptionManager,
                    configuration: subscriptionConfiguration
                )
            }
        }
    }

    private var stateDescription: String {
        switch subscriptionManager.state {
        case .unknown:
            "Unknown"
        case .loading:
            "Loading"
        case .premium:
            "Premium"
        case .premiumFromSnapshot:
            "Premium snapshot"
        case .nonPremium:
            "Non-premium"
        case .failed(let message):
            "Failed: \(message)"
        }
    }

    private var paywallModeDescription: String {
        switch subscriptionConfiguration.paywallMode {
        case .revenueCat:
            "RevenueCat hosted"
        case .custom:
            "Custom SwiftUI"
        case .scrollTemplateView:
            "Scroll template SwiftUI"
        case .customProvider:
            "Custom provider SwiftUI"
        }
    }
}

#Preview {
    ContentView(
        subscriptionManager: SubscriptionManager(),
        subscriptionConfiguration: SubscriptionKitConfiguration(publicAPIKey: "preview")
    )
}
