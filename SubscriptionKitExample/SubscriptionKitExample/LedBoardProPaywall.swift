
//
//  LedBoardProPaywall.swift
//  SubscriptionKitExample
//
//  Custom paywall provider for LED Board Pro, using the customProvider API.
//

import SubscriptionKit
import SwiftUI

// MARK: - Provider

/// Conforms to `SubscriptionCustomPaywallProviding` so it can be passed
/// directly into `.customProvider(...)` / `.custom(provider:)`.
@MainActor
struct LedBoardProPaywallProvider: SubscriptionCustomPaywallProviding {
    func makePaywall(context: SubscriptionPaywallContext) -> some View {
        LedBoardProPaywallView(context: context)
    }
}

// MARK: - Root View

private struct LedBoardProPaywallView: View {
    @ObservedObject var context: SubscriptionPaywallContext

    // Accent / palette
    private let accent      = Color.cyan
    private let bgTop       = Color(red: 0.03, green: 0.04, blue: 0.10)
    private let bgBottom    = Color(red: 0.00, green: 0.02, blue: 0.06)
    private let panelFill   = Color.white.opacity(0.07)
    private let secondaryFg = Color.white.opacity(0.65)

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-screen gradient background
            LinearGradient(
                colors: [bgTop, bgBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Decorative radial glow
            RadialGradient(
                colors: [accent.opacity(0.18), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 380
            )
            .ignoresSafeArea()

            // Content
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        topBar
                        heroSection
                        featuresSection
                        planSection
                        moreInfoSection
                        Spacer(minLength: 120) // clearance for bottom bar
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }

                bottomBar
            }
        }
        .foregroundStyle(.white)
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack {
            // App wordmark
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.led.fill")
                    .foregroundStyle(accent)
                Text("LED Board Pro")
                    .font(.headline)
            }

            Spacer()

            Button(action: context.dismiss) {
                Text("Not now")
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close paywall")
        }
        .padding(.top, 8)
    }

    // MARK: Hero

    private var heroSection: some View {
        VStack(spacing: 16) {
            // Glowing icon badge
            ZStack {
                Circle()
                    .fill(accent.opacity(0.15))
                    .frame(width: 110, height: 110)
                Circle()
                    .stroke(accent.opacity(0.5), lineWidth: 1)
                    .frame(width: 110, height: 110)
                Image(systemName: "textformat.size")
                    .font(.system(size: 46, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .shadow(color: accent.opacity(0.45), radius: 28)

            // Headline with coloured segment
            (Text("Create brighter ")
                .foregroundColor(.white, ) +
             Text("LED banners")
                .foregroundColor(accent))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Text("Unlock premium text effects, saved boards, and advanced display controls.")
                .font(.body)
                .foregroundStyle(secondaryFg)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 320)
        }
        .padding(.top, 8)
    }

    // MARK: Features

    private let features: [(icon: String, title: String, subtitle: String)] = [
        ("sparkles",              "Premium effects",   "Advanced animations, glow, and marquee styles."),
        ("rectangle.stack.fill", "Unlimited boards",  "Save every sign and switch fast."),
        ("slider.horizontal.3",  "Full controls",     "Tune speed, colour, and display behaviour."),
    ]

    private var featuresSection: some View {
        VStack(spacing: 14) {
            ForEach(features, id: \.title) { feature in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: feature.icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(accent)
                        .frame(width: 28)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(feature.title)
                            .font(.headline)
                        Text(feature.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(secondaryFg)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(18)
        .background(panelFill, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: Plan picker

    private var planSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose your access")
                .font(.title3.bold())

            if context.state == .loading && context.packages.isEmpty {
                ProgressView()
                    .tint(accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if context.packages.isEmpty {
                Text("No plans available at the moment.")
                    .font(.subheadline)
                    .foregroundStyle(secondaryFg)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 10) {
                    ForEach(context.packages) { package in
                        PlanCard(
                            package: package,
                            isSelected: context.selectedPackage?.id == package.id,
                            accent: accent,
                            secondaryFg: secondaryFg,
                            panelFill: panelFill
                        )
                        .onTapGesture {
                            context.selectPackage(package)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: More info

    private let moreInfoRows: [(title: String, subtitle: String)] = [
        ("Cancel anytime",       "Manage or cancel from your App Store account settings."),
        ("Works across devices", "Restore on any device signed in with the same Apple ID."),
    ]

    private var moreInfoSection: some View {
        VStack(spacing: 10) {
            ForEach(moreInfoRows, id: \.title) { row in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(accent)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.title)
                            .font(.subheadline.weight(.semibold))
                        Text(row.subtitle)
                            .font(.footnote)
                            .foregroundStyle(secondaryFg)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 10) {
            // Purchase button
            Button {
                guard let package = context.selectedPackage else { return }
                Task { await context.purchase(package) }
            } label: {
                HStack(spacing: 10) {
                    if context.isPurchasing {
                        ProgressView()
                            .tint(.black)
                    }
                    Text("Continue")
                        .font(.headline)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [accent, accent.opacity(0.75)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .foregroundStyle(.black)
                .shadow(color: accent.opacity(0.5), radius: 12, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(context.packages.isEmpty || context.isPurchasing)
            .opacity(context.packages.isEmpty ? 0.5 : 1)
            .accessibilityLabel("Continue with purchase")

            // Restore + legal row
            HStack(spacing: 16) {
                Button {
                    Task { await context.restorePurchases() }
                } label: {
                    if context.isRestoring {
                        ProgressView().tint(secondaryFg)
                    } else {
                        Text("Restore")
                    }
                }
                .disabled(context.isRestoring)

                Link("Terms",   destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link("Privacy", destination: URL(string: "https://www.apple.com/legal/privacy/")!)
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(secondaryFg)

            if let error = context.lastError {
                Text(error.localizedDescription)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
        .padding(.bottom, 20)
        .background(.ultraThinMaterial)
        .background(bgBottom.opacity(0.92))
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let package: SubscriptionPackage
    let isSelected: Bool
    let accent: Color
    let secondaryFg: Color
    let panelFill: Color

    private var title: String {
        switch package.productType {
        case .lifetime: "Lifetime"
        case .yearly:   "Yearly"
        case .monthly:  "Monthly"
        case .weekly:   "Weekly"
        case .custom, .unknown: package.title
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                .imageScale(.large)
                .foregroundStyle(isSelected ? accent : secondaryFg)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                        .lineLimit(1)

                    if package.productType == .yearly {
                        Text("Best value")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(accent, in: Capsule())
                            .foregroundStyle(.black)
                    }
                }
                Text(package.localizedDescription)
                    .font(.subheadline)
                    .foregroundStyle(secondaryFg)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 3) {
                Text(package.localizedPrice)
                    .font(.headline)
                if let period = package.periodDescription {
                    Text(period)
                        .font(.caption)
                        .foregroundStyle(secondaryFg)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(15)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? accent.opacity(0.15) : panelFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? accent : Color.white.opacity(0.1), lineWidth: 1.5)
        )
    }
}
