//
//  SubscriptionKitExampleApp.swift
//  SubscriptionKitExample
//
//  Created by SixBlack on 13/6/26.
//

import SubscriptionKit
import SwiftUI
import SwiftInjected

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        NSLog("AppDelegate didFinishLaunchingWithOptions CALLED")
        // Configure dependencies
        let dependencies = Dependencies {
            Dependency { SubscriptionManager.shared }
        }
        dependencies.build()

        let subscriptionConfiguration = SubscriptionKitConfiguration(
            publicAPIKey: "appl_LvbEgoxTobVLwlXVUwdUkTRnHoU",
            entitlementID: "SixPilot/LedBoard Pro",
            paywallMode: .custom(provider: LedBoardProPaywallProvider()),
            debugLoggingEnabled: true
        )
        SubscriptionManager.shared.setConfiguration(subscriptionConfiguration)
        
        Task {
            NSLog("Task started execution")
            do {
                try await SubscriptionManager.shared.configure(subscriptionConfiguration, refreshOnConfigure: true)
            } catch {
                NSLog("Configure error: \(error)")
            }
        }

        return true
    }
}

@main
struct SubscriptionKitExampleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
