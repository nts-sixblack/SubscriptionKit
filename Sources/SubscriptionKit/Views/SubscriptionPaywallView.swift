import RevenueCatUI
import SwiftUI

// MARK: - SubscriptionPaywallView

/// The root paywall view for SubscriptionKit.
///
/// Renders the paywall implementation selected by
/// ``SubscriptionKitConfiguration/paywallMode``.
///
/// Present this view modally — typically with `.sheet`:
///
/// ```swift
/// .sheet(isPresented: $isShowingPaywall) {
///     SubscriptionPaywallView(
///         manager: subscriptionManager,
///         configuration: subscriptionConfiguration
///     )
/// }
/// ```
public struct SubscriptionPaywallView: View {
    @ObservedObject var manager: SubscriptionManager
    let configuration: SubscriptionKitConfiguration
    @Environment(\.dismiss) private var dismiss

    public init(manager: SubscriptionManager, configuration: SubscriptionKitConfiguration) {
        self.manager = manager
        self.configuration = configuration
    }

    public var body: some View {
        Group {
            switch configuration.paywallMode {
            case .revenueCat:
                RevenueCatHostedPaywallView(
                    manager: manager,
                    configuration: configuration,
                    dismiss: dismiss
                )
            case .custom:
                CustomSubscriptionPaywallView(
                    manager: manager,
                    configuration: configuration,
                    dismiss: dismiss
                )
            case .scrollTemplateView(let content):
                ScrollTemplateSubscriptionPaywallView(
                    manager: manager,
                    configuration: configuration,
                    content: content,
                    dismiss: dismiss
                )
            case .customProvider(let provider):
                CustomProviderPaywallView(
                    manager: manager,
                    configuration: configuration,
                    provider: provider,
                    dismiss: dismiss
                )
            }
        }
    }
}

// MARK: - RevenueCatHostedPaywallView

private struct RevenueCatHostedPaywallView: View {
    @ObservedObject var manager: SubscriptionManager
    let configuration: SubscriptionKitConfiguration
    let dismiss: DismissAction

    var body: some View {
        PaywallView(displayCloseButton: configuration.showsCloseButton)
            .onPurchaseCompleted { _ in
                Task {
                    await manager.refreshCustomerInfo()
                    dismiss()
                }
            }
            .onRestoreCompleted { _ in
                Task {
                    await manager.refreshCustomerInfo()
                    dismiss()
                }
            }
            .onRequestedDismissal {
                dismiss()
            }
    }
}

// MARK: - CustomSubscriptionPaywallView

private struct CustomSubscriptionPaywallView: View {
    @ObservedObject var manager: SubscriptionManager
    let configuration: SubscriptionKitConfiguration
    let dismiss: DismissAction
    @State private var selectedPackageID: SubscriptionPackage.ID?

    private var selectedPackage: SubscriptionPackage? {
        manager.packages.first { $0.id == selectedPackageID } ?? manager.packages.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    benefits
                    packageList
                    actionArea
                    legalLinks
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(configuration.theme.backgroundColor)
            .foregroundStyle(configuration.theme.foregroundColor)
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if configuration.showsCloseButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close", action: dismiss.callAsFunction)
                            .accessibilityLabel("Close paywall")
                    }
                }
            }
        }
        .onAppear {
            if selectedPackageID == nil {
                selectedPackageID = manager.packages.first?.id
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(configuration.customPaywall.title)
                .font(.largeTitle.bold())
                .fixedSize(horizontal: false, vertical: true)
            Text(configuration.customPaywall.subtitle)
                .font(.body)
                .foregroundStyle(configuration.theme.secondaryForegroundColor)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(configuration.customPaywall.benefits, id: \.self) { benefit in
                Label(benefit, systemImage: "checkmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(configuration.theme.foregroundColor)
                    .labelStyle(.titleAndIcon)
                    .accessibilityLabel(benefit)
            }
        }
    }

    @ViewBuilder
    private var packageList: some View {
        if manager.packages.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "cart.badge.questionmark")
                    .font(.title2)
                    .foregroundStyle(configuration.theme.secondaryForegroundColor)
                Text(configuration.customPaywall.emptyOfferingTitle)
                    .font(.headline)
                Text(configuration.customPaywall.emptyOfferingMessage)
                    .font(.subheadline)
                    .foregroundStyle(configuration.theme.secondaryForegroundColor)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
        } else {
            VStack(spacing: 12) {
                ForEach(manager.packages) { package in
                    Button {
                        selectedPackageID = package.id
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: selectedPackageID == package.id ? "largecircle.fill.circle" : "circle")
                                .imageScale(.large)
                                .foregroundStyle(configuration.theme.accentColor)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(displayTitle(for: package))
                                    .font(.headline)
                                Text(package.localizedDescription)
                                    .font(.subheadline)
                                    .foregroundStyle(configuration.theme.secondaryForegroundColor)
                                    .lineLimit(2)
                            }

                            Spacer(minLength: 12)

                            VStack(alignment: .trailing, spacing: 4) {
                                Text(package.localizedPrice)
                                    .font(.headline)
                                if let period = package.periodDescription {
                                    Text(period)
                                        .font(.caption)
                                        .foregroundStyle(configuration.theme.secondaryForegroundColor)
                                }
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedPackageID == package.id ? configuration.theme.accentColor : .clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(displayTitle(for: package)), \(package.localizedPrice)")
                }
            }
        }
    }

    private var actionArea: some View {
        VStack(spacing: 12) {
            Button {
                guard let selectedPackage else { return }
                Task {
                    await manager.purchase(package: selectedPackage)
                    if manager.isPremium {
                        dismiss()
                    }
                }
            } label: {
                HStack {
                    if manager.isPurchasing {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(configuration.customPaywall.purchaseButtonTitle)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(configuration.theme.accentColor)
            .disabled(selectedPackage == nil || manager.isPurchasing)
            .accessibilityLabel(configuration.customPaywall.purchaseButtonTitle)

            if configuration.showsRestoreButton {
                Button {
                    Task {
                        await manager.restorePurchases()
                        if manager.isPremium {
                            dismiss()
                        }
                    }
                } label: {
                    if manager.isRestoring {
                        ProgressView()
                    } else {
                        Text(configuration.customPaywall.restoreButtonTitle)
                    }
                }
                .buttonStyle(.borderless)
                .disabled(manager.isRestoring)
                .accessibilityLabel(configuration.customPaywall.restoreButtonTitle)
            }

            if let error = manager.lastError {
                Text(error.localizedDescription)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Purchase error: \(error.localizedDescription)")
            }
        }
    }

    private var legalLinks: some View {
        HStack(spacing: 16) {
            ForEach(configuration.customPaywall.legalLinks) { link in
                Link(link.title, destination: link.url)
                    .font(.footnote)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func displayTitle(for package: SubscriptionPackage) -> String {
        switch package.productType {
        case .lifetime: "Lifetime"
        case .yearly:   "Yearly"
        case .monthly:  "Monthly"
        case .weekly:   "Weekly"
        case .custom, .unknown: package.title
        }
    }
}

// MARK: - CustomProviderPaywallView

private struct CustomProviderPaywallView: View {
    @ObservedObject var manager: SubscriptionManager
    let configuration: SubscriptionKitConfiguration
    let provider: AnySubscriptionCustomPaywallProvider
    let dismiss: DismissAction

    /// Keep the context alive for the lifetime of the sheet so Combine
    /// subscriptions remain active while the paywall is on screen.
    @StateObject private var context: SubscriptionPaywallContext

    init(
        manager: SubscriptionManager,
        configuration: SubscriptionKitConfiguration,
        provider: AnySubscriptionCustomPaywallProvider,
        dismiss: DismissAction
    ) {
        self.manager = manager
        self.configuration = configuration
        self.provider = provider
        self.dismiss = dismiss
        _context = StateObject(wrappedValue: SubscriptionPaywallContext(
            manager: manager,
            configuration: configuration,
            dismiss: dismiss.callAsFunction
        ))
    }

    var body: some View {
        provider.makePaywall(context: context)
    }
}
