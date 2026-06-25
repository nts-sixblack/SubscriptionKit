import Foundation
import SwiftUI
import SwiftInjected

// MARK: - ScrollTemplateSubscriptionPaywallView

/// The built-in scroll-template paywall.
///
/// Features a hero icon, multi-colour headline, feature panel, star rating block,
/// scrollable plan selector with optional plan overrides, and a sticky bottom bar
/// with purchase and restore buttons.
///
/// Configure the full appearance via ``SubscriptionScrollTemplatePaywallContent``.
///
/// ```swift
/// let content = SubscriptionScrollTemplatePaywallContent(
///     appTitle: "My App",
///     backgroundColor: Color(red: 0.04, green: 0.05, blue: 0.09),
///     heroIcon: Image(systemName: "star.fill"),
///     headlineSegments: [
///         .init(text: "Go ", color: .white),
///         .init(text: "Pro", color: .cyan)
///     ],
///     subtitle: "Unlock everything.",
///     features: [
///         .init(icon: Image(systemName: "sparkles"), title: "Feature 1", subtitle: "Details")
///     ],
///     rating: .init(score: "4.9", title: "Top rated", subtitle: "By our users"),
///     planSectionTitle: "Choose a plan",
///     purchaseButtonTitle: "Continue",
///     restoreButtonTitle: "Restore",
///     skipButtonTitle: "Not now",
///     emptyOfferingTitle: "No plans",
///     emptyOfferingMessage: "Check RevenueCat.",
///     legalLinks: [
///         .init(title: "Terms", url: URL(string: "https://example.com/terms")!)
///     ],
///     palette: .init(
///         accent: .cyan,
///         background: Color(red: 0.04, green: 0.05, blue: 0.09),
///         foreground: .white,
///         secondaryForeground: .white.opacity(0.72),
///         panelBackground: .white.opacity(0.12),
///         planBackground: .white.opacity(0.09),
///         selectedPlanBackground: .cyan.opacity(0.18),
///         selectedPlanBorder: .cyan,
///         bottomBarBackground: Color(red: 0.04, green: 0.05, blue: 0.09).opacity(0.96)
///     )
/// )
///
/// let config = SubscriptionKitConfiguration(
///     publicAPIKey: "appl_xxx",
///     paywallMode: .scrollTemplateView(content: content)
/// )
/// ```
public struct ScrollTemplateSubscriptionPaywallView: View {
    @InjectedObservable var manager: SubscriptionManager
    let content: SubscriptionScrollTemplatePaywallContent
    let dismiss: () -> Void
    @State private var selectedPackageID: SubscriptionPackage.ID?

    public init(
        content: SubscriptionScrollTemplatePaywallContent,
        dismiss: @escaping () -> Void
    ) {
        self.content = content
        self.dismiss = dismiss
    }

    private var palette: SubscriptionScrollTemplatePaywallContent.Palette {
        content.palette
    }

    private var selectedPackage: SubscriptionPackage? {
        manager.packages.first { $0.id == selectedPackageID } ?? manager.packages.first
    }

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    topBar
                    header
                    featurePanel
                    ratingRow
                    planSection
                    moreInfoSection
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28)
                .background {
                    background
                }
            }
            bottomPurchaseArea
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .background(palette.bottomBarBackground)
        }
        .foregroundStyle(palette.foreground)
        .onAppear(perform: selectInitialPackageIfNeeded)
        .onChange(of: manager.packages) { _ in
            selectInitialPackageIfNeeded()
        }
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            content.backgroundColor
            if let backgroundImage = content.backgroundImage {
                backgroundImage
                    .resizable()
                    .scaledToFill()
                    .opacity(0.14)
                    .blur(radius: 1)
            }
            LinearGradient(
                colors: [
                    .black.opacity(0.12),
                    content.backgroundColor.opacity(0.82),
                    content.backgroundColor
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Text(content.appTitle)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            if manager.configuration?.showsCloseButton == true {
                Button(action: dismiss) {
                    Text(content.skipButtonTitle)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(content.skipButtonTitle)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 16) {
            content.heroIcon
                .resizable()
                .scaledToFit()
                .frame(width: 74, height: 74)
                .padding(18)
                .background(
                    Circle()
                        .fill(palette.panelBackground)
                )
                .overlay(
                    Circle()
                        .stroke(palette.accent.opacity(0.7), lineWidth: 1)
                )
                .foregroundStyle(palette.accent)
                .accessibilityHidden(true)

            headline

            Text(content.subtitle)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(palette.secondaryForeground)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 340)
        }
        .padding(.top, 12)
    }

    private var headline: some View {
        Text(headlineAttributedString)
            .font(.system(size: 36, weight: .bold, design: .rounded))
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .minimumScaleFactor(0.75)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var headlineAttributedString: AttributedString {
        content.headlineSegments.reduce(into: AttributedString()) { result, segment in
            var attributedSegment = AttributedString(segment.text)
            attributedSegment.foregroundColor = segment.color
            result.append(attributedSegment)
        }
    }

    // MARK: - Feature Panel

    private var featurePanel: some View {
        VStack(spacing: 14) {
            ForEach(Array(content.features.enumerated()), id: \.offset) { _, feature in
                HStack(alignment: .top, spacing: 12) {
                    feature.icon
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(palette.accent)
                        .frame(width: 28)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(feature.title)
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(feature.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryForeground)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 0)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(palette.panelBackground)
        )
    }

    // MARK: - Rating Row

    private var ratingRow: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(content.rating.score)
                    .font(.title2.bold())
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }
                .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(content.rating.title)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text(content.rating.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryForeground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(palette.panelBackground)
        )
    }

    // MARK: - Plan Section

    @ViewBuilder
    private var planSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(content.planSectionTitle)
                .font(.title3.bold())

            if manager.state == .loading {
                ProgressView()
                    .tint(palette.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if manager.packages.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "cart.badge.questionmark")
                        .font(.title2)
                        .foregroundStyle(palette.secondaryForeground)
                    Text(content.emptyOfferingTitle)
                        .font(.headline)
                    Text(content.emptyOfferingMessage)
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryForeground)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 10) {
                    ForEach(manager.packages) { package in
                        planButton(for: package)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func planButton(for package: SubscriptionPackage) -> some View {
        let selected = selectedPackage?.id == package.id
        let override = planOverride(for: package)

        return Button {
            selectedPackageID = package.id
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .imageScale(.large)
                    .foregroundStyle(selected ? palette.selectedPlanBorder : palette.secondaryForeground)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(override?.title ?? displayTitle(for: package))
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .layoutPriority(1)

                        if let badge = override?.badge {
                            Text(badge)
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(palette.accent, in: Capsule())
                                .foregroundStyle(content.backgroundColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                    }

                    Text(override?.subtitle ?? package.localizedDescription)
                        .font(.subheadline)
                        .foregroundStyle(palette.secondaryForeground)
                        .lineLimit(2)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(package.localizedPrice)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if let period = package.periodDescription {
                        Text(period)
                            .font(.caption)
                            .foregroundStyle(palette.secondaryForeground)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(15)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? palette.selectedPlanBackground : palette.planBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? palette.selectedPlanBorder : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(override?.title ?? displayTitle(for: package)), \(package.localizedPrice)")
    }

    // MARK: - More Info Section

    private var moreInfoSection: some View {
        VStack(spacing: 10) {
            ForEach(Array(content.moreInfoRows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(palette.accent)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.title)
                            .font(.subheadline.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(row.subtitle)
                            .font(.footnote)
                            .foregroundStyle(palette.secondaryForeground)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Bottom Bar

    private var bottomPurchaseArea: some View {
        VStack(spacing: 10) {
            Button {
                guard let selectedPackage else { return }
                Task {
                    await manager.purchase(package: selectedPackage)
                    if manager.isPremium {
                        dismiss()
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    if manager.isPurchasing {
                        ProgressView()
                            .tint(content.backgroundColor)
                    }
                    Text(content.purchaseButtonTitle)
                        .font(.headline)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(palette.accent, in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(content.backgroundColor)
            }
            .buttonStyle(.plain)
            .disabled(selectedPackage == nil || manager.isPurchasing)
            .opacity(selectedPackage == nil ? 0.55 : 1)
            .accessibilityLabel(content.purchaseButtonTitle)

            if manager.configuration?.showsRestoreButton == true || !content.legalLinks.isEmpty {
                HStack(spacing: 14) {
                    if manager.configuration?.showsRestoreButton == true {
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
                                    .tint(palette.secondaryForeground)
                            } else {
                                Text(content.restoreButtonTitle)
                            }
                        }
                        .disabled(manager.isRestoring)
                    }

                    ForEach(content.legalLinks) { link in
                        Link(link.title, destination: link.url)
                    }
                }
                .font(.footnote.weight(.medium))
                .foregroundStyle(palette.secondaryForeground)
            }

            if let error = manager.lastError {
                Text(error.localizedDescription)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Purchase error: \(error.localizedDescription)")
            }
        }
        .padding(.top, 14)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func selectInitialPackageIfNeeded() {
        guard selectedPackageID == nil || !manager.packages.contains(where: { $0.id == selectedPackageID }) else { return }
        selectedPackageID = manager.configuration?.resolvedDefaultPackage(from: manager.packages)?.id
    }

    private func planOverride(for package: SubscriptionPackage) -> SubscriptionScrollTemplatePaywallContent.PlanOverride? {
        content.planOverrides.first { override in
            override.packageID == package.id || override.productIdentifier == package.productIdentifier
        }
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
