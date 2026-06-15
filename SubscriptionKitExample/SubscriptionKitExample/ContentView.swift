//
//  ContentView.swift
//  SubscriptionKitExample
//
//  Created by SixBlack on 13/6/26.
//

import SubscriptionKit
import SwiftUI
import SwiftInjected

struct ContentView: View {
    @InjectedObservable var subscriptionManager: SubscriptionManager
    @State private var isShowingPaywall = true

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

                Section("Debug") {
                    Button("Print Manager Address") {
                        NSLog("Manager: \(Unmanaged.passUnretained(subscriptionManager).toOpaque())")
                        NSLog("Shared: \(Unmanaged.passUnretained(SubscriptionManager.shared).toOpaque())")
                    }
                }
            }
            .navigationTitle("SubscriptionKit")
            .sheet(isPresented: $isShowingPaywall) {
                SubscriptionPaywallView()
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
        guard let configuration = subscriptionManager.configuration else {
            return "Unconfigured"
        }
        switch configuration.paywallMode {
        case .revenueCat:
            return "RevenueCat hosted"
        case .custom:
            return "Custom SwiftUI"
        case .scrollTemplateView:
            return "Scroll template SwiftUI"
        case .customProvider:
            return "Custom provider SwiftUI"
        }
    }
}

#Preview {
    let _ = Dependencies {
        Dependency { SubscriptionManager() }
    }.build()

    return ContentView()
}
