import Combine
import SwiftUI
import SwiftInjected

// MARK: - SubscriptionKitConfiguration

/// The root configuration object for SubscriptionKit.
///
/// Create one instance per app launch and pass it to
/// ``SubscriptionManager/configure(_:refreshOnConfigure:)`` and
/// ``SubscriptionPaywallView``.
///
/// ```swift
/// let config = SubscriptionKitConfiguration(
///     publicAPIKey: "appl_your_revenuecat_ios_key",
///     entitlementID: "premium",
///     paywallMode: .custom
/// )
/// ```
public struct SubscriptionKitConfiguration {

    // MARK: - PaywallMode

    /// Selects which paywall implementation SubscriptionKit renders.
    public enum PaywallMode {
        /// RevenueCat-hosted paywall rendered via `RevenueCatUI.PaywallView`.
        case revenueCat
        /// The built-in custom SwiftUI paywall driven by `SubscriptionCustomPaywallContent`.
        case custom
        /// The built-in scroll-template SwiftUI paywall with hero, features, rating, and plans.
        case scrollTemplateView(content: SubscriptionScrollTemplatePaywallContent)
        /// A fully custom SwiftUI paywall supplied by the caller via the
        /// ``SubscriptionCustomPaywallProviding`` protocol.
        case customProvider(AnySubscriptionCustomPaywallProvider)
    }

    // MARK: - ValidationError

    /// Errors thrown by ``SubscriptionKitConfiguration/validate()``.
    public enum ValidationError: Error, Equatable, LocalizedError {
        case missingPublicAPIKey

        public var errorDescription: String? {
            switch self {
            case .missingPublicAPIKey:
                return "RevenueCat public API key is missing."
            }
        }
    }

    // MARK: - Properties

    /// RevenueCat public SDK API key.
    ///
    /// Use a Test Store key **only** for development and the platform-specific
    /// iOS key for production / TestFlight / App Review.
    public var publicAPIKey: String

    /// RevenueCat entitlement identifier that represents premium access.
    ///
    /// Defaults to `"premium"`. Must match the entitlement created in the
    /// RevenueCat dashboard.
    public var entitlementID: String

    /// Optional stable user ID passed to RevenueCat during SDK configuration.
    ///
    /// Use this when your app has authenticated users. If `nil`, RevenueCat
    /// generates an anonymous App User ID.
    public var appUserID: String?

    /// Selects the paywall implementation.
    public var paywallMode: PaywallMode

    /// Optional RevenueCat offering identifier.
    ///
    /// If provided, packages are fetched via `offerings.offering(identifier:)`.
    /// If `nil`, the SDK falls back to `placementIdentifier`, then to the
    /// current offering.
    public var offeringIdentifier: String?

    /// Optional RevenueCat targeting placement identifier.
    ///
    /// Used only when `offeringIdentifier` is `nil`.
    public var placementIdentifier: String?

    /// Display order of packages in the built-in paywalls.
    ///
    /// Defaults to `[.lifetime, .yearly, .monthly, .weekly]`. Unknown/custom
    /// types are sorted after all configured types.
    public var productOrder: [SubscriptionProductType]

    /// Text and links for the built-in custom SwiftUI paywall.
    public var customPaywall: SubscriptionCustomPaywallContent

    /// Whether to show a close / skip button in the paywall.
    public var showsCloseButton: Bool

    /// Whether to show the "Restore Purchases" button in built-in paywalls.
    public var showsRestoreButton: Bool

    /// Colors used by the built-in custom SwiftUI paywall.
    public var theme: SubscriptionPaywallTheme

    /// Enables RevenueCat debug logging (`Purchases.logLevel = .debug`).
    ///
    /// Keep `false` in production builds.
    public var debugLoggingEnabled: Bool

    /// `UserDefaults` key used to persist the premium state snapshot.
    public var snapshotStorageKey: String

    // MARK: - Init

    public init(
        publicAPIKey: String,
        entitlementID: String = "premium",
        appUserID: String? = nil,
        paywallMode: PaywallMode = .custom,
        offeringIdentifier: String? = nil,
        placementIdentifier: String? = nil,
        productOrder: [SubscriptionProductType] = [.lifetime, .yearly, .monthly, .weekly],
        customPaywall: SubscriptionCustomPaywallContent = .default,
        showsCloseButton: Bool = true,
        showsRestoreButton: Bool = true,
        theme: SubscriptionPaywallTheme = .default,
        debugLoggingEnabled: Bool = false,
        snapshotStorageKey: String = "SubscriptionKit.PremiumSnapshot"
    ) {
        self.publicAPIKey = publicAPIKey
        self.entitlementID = entitlementID
        self.appUserID = appUserID
        self.paywallMode = paywallMode
        self.offeringIdentifier = offeringIdentifier
        self.placementIdentifier = placementIdentifier
        self.productOrder = productOrder
        self.customPaywall = customPaywall
        self.showsCloseButton = showsCloseButton
        self.showsRestoreButton = showsRestoreButton
        self.theme = theme
        self.debugLoggingEnabled = debugLoggingEnabled
        self.snapshotStorageKey = snapshotStorageKey
    }

    // MARK: - Validation

    /// Validates the configuration, throwing if required fields are missing.
    public func validate() throws {
        guard !publicAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.missingPublicAPIKey
        }
    }
}

// MARK: - PaywallMode Convenience

public extension SubscriptionKitConfiguration.PaywallMode {
    /// Returns a `.customProvider` mode wrapping the given provider in a type-erased container.
    ///
    /// ```swift
    /// let config = SubscriptionKitConfiguration(
    ///     publicAPIKey: "appl_xxx",
    ///     paywallMode: .custom(provider: MyPaywall())
    /// )
    /// ```
    @MainActor
    static func custom<P: SubscriptionCustomPaywallProviding>(
        provider: P
    ) -> SubscriptionKitConfiguration.PaywallMode {
        .customProvider(AnySubscriptionCustomPaywallProvider(provider))
    }
}

// MARK: - SubscriptionCustomPaywallContent

/// Copy, benefits, and legal links for the built-in custom SwiftUI paywall.
public struct SubscriptionCustomPaywallContent: Equatable {

    /// A tappable legal link shown at the bottom of the paywall.
    public struct LegalLink: Identifiable, Equatable {
        public var id: String { title }
        public var title: String
        public var url: URL

        public init(title: String, url: URL) {
            self.title = title
            self.url = url
        }
    }

    public var title: String
    public var subtitle: String
    public var benefits: [String]
    public var purchaseButtonTitle: String
    public var restoreButtonTitle: String
    public var emptyOfferingTitle: String
    public var emptyOfferingMessage: String
    public var legalLinks: [LegalLink]

    public init(
        title: String,
        subtitle: String,
        benefits: [String],
        purchaseButtonTitle: String,
        restoreButtonTitle: String,
        emptyOfferingTitle: String,
        emptyOfferingMessage: String,
        legalLinks: [LegalLink]
    ) {
        self.title = title
        self.subtitle = subtitle
        self.benefits = benefits
        self.purchaseButtonTitle = purchaseButtonTitle
        self.restoreButtonTitle = restoreButtonTitle
        self.emptyOfferingTitle = emptyOfferingTitle
        self.emptyOfferingMessage = emptyOfferingMessage
        self.legalLinks = legalLinks
    }

    /// Sensible defaults ready for drop-in use.
    public static let `default` = SubscriptionCustomPaywallContent(
        title: "Unlock Premium",
        subtitle: "Get every premium feature and keep access across devices.",
        benefits: [
            "Unlimited premium access",
            "Sync purchases with your RevenueCat account",
            "Restore subscriptions at any time"
        ],
        purchaseButtonTitle: "Continue",
        restoreButtonTitle: "Restore Purchases",
        emptyOfferingTitle: "No products available",
        emptyOfferingMessage: "RevenueCat did not return packages for this offering.",
        legalLinks: [
            .init(title: "Terms", url: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!),
            .init(title: "Privacy", url: URL(string: "https://www.apple.com/legal/privacy/")!)
        ]
    )
}

// MARK: - SubscriptionScrollTemplatePaywallContent

/// Full content model for the built-in scroll-template paywall.
public struct SubscriptionScrollTemplatePaywallContent {

    /// A coloured text segment that forms the multi-colour headline.
    public struct HeadlineSegment {
        public var text: String
        public var color: Color

        public init(text: String, color: Color) {
            self.text = text
            self.color = color
        }
    }

    /// A single feature row shown in the feature panel.
    public struct FeatureRow {
        public var icon: Image
        public var title: String
        public var subtitle: String

        public init(icon: Image, title: String, subtitle: String) {
            self.icon = icon
            self.title = title
            self.subtitle = subtitle
        }
    }

    /// The star rating block displayed below the feature panel.
    public struct RatingBlock {
        public var score: String
        public var title: String
        public var subtitle: String

        public init(score: String, title: String, subtitle: String) {
            self.score = score
            self.title = title
            self.subtitle = subtitle
        }
    }

    /// Overrides the display title, subtitle, or badge for a specific package.
    public struct PlanOverride {
        public var packageID: String?
        public var productIdentifier: String?
        public var title: String
        public var subtitle: String?
        public var badge: String?

        public init(
            packageID: String? = nil,
            productIdentifier: String? = nil,
            title: String,
            subtitle: String? = nil,
            badge: String? = nil
        ) {
            self.packageID = packageID
            self.productIdentifier = productIdentifier
            self.title = title
            self.subtitle = subtitle
            self.badge = badge
        }
    }

    /// An informational row shown below the plan selector.
    public struct MoreInfoRow {
        public var title: String
        public var subtitle: String

        public init(title: String, subtitle: String) {
            self.title = title
            self.subtitle = subtitle
        }
    }

    /// A tappable legal link shown in the bottom bar.
    public struct LegalLink: Identifiable, Equatable {
        public var id: String { title }
        public var title: String
        public var url: URL

        public init(title: String, url: URL) {
            self.title = title
            self.url = url
        }
    }

    /// The full color palette for the scroll-template paywall.
    public struct Palette {
        public var accent: Color
        public var background: Color
        public var foreground: Color
        public var secondaryForeground: Color
        public var panelBackground: Color
        public var planBackground: Color
        public var selectedPlanBackground: Color
        public var selectedPlanBorder: Color
        public var bottomBarBackground: Color

        public init(
            accent: Color,
            background: Color,
            foreground: Color,
            secondaryForeground: Color,
            panelBackground: Color,
            planBackground: Color,
            selectedPlanBackground: Color,
            selectedPlanBorder: Color,
            bottomBarBackground: Color
        ) {
            self.accent = accent
            self.background = background
            self.foreground = foreground
            self.secondaryForeground = secondaryForeground
            self.panelBackground = panelBackground
            self.planBackground = planBackground
            self.selectedPlanBackground = selectedPlanBackground
            self.selectedPlanBorder = selectedPlanBorder
            self.bottomBarBackground = bottomBarBackground
        }
    }

    public var appTitle: String
    public var backgroundImage: Image?
    public var backgroundColor: Color
    public var heroIcon: Image
    public var headlineSegments: [HeadlineSegment]
    public var subtitle: String
    public var features: [FeatureRow]
    public var rating: RatingBlock
    public var planSectionTitle: String
    public var planOverrides: [PlanOverride]
    public var moreInfoRows: [MoreInfoRow]
    public var purchaseButtonTitle: String
    public var restoreButtonTitle: String
    public var skipButtonTitle: String
    public var emptyOfferingTitle: String
    public var emptyOfferingMessage: String
    public var legalLinks: [LegalLink]
    public var palette: Palette

    public init(
        appTitle: String,
        backgroundImage: Image? = nil,
        backgroundColor: Color,
        heroIcon: Image,
        headlineSegments: [HeadlineSegment],
        subtitle: String,
        features: [FeatureRow],
        rating: RatingBlock,
        planSectionTitle: String,
        planOverrides: [PlanOverride] = [],
        moreInfoRows: [MoreInfoRow] = [],
        purchaseButtonTitle: String,
        restoreButtonTitle: String,
        skipButtonTitle: String,
        emptyOfferingTitle: String,
        emptyOfferingMessage: String,
        legalLinks: [LegalLink],
        palette: Palette
    ) {
        self.appTitle = appTitle
        self.backgroundImage = backgroundImage
        self.backgroundColor = backgroundColor
        self.heroIcon = heroIcon
        self.headlineSegments = headlineSegments
        self.subtitle = subtitle
        self.features = features
        self.rating = rating
        self.planSectionTitle = planSectionTitle
        self.planOverrides = planOverrides
        self.moreInfoRows = moreInfoRows
        self.purchaseButtonTitle = purchaseButtonTitle
        self.restoreButtonTitle = restoreButtonTitle
        self.skipButtonTitle = skipButtonTitle
        self.emptyOfferingTitle = emptyOfferingTitle
        self.emptyOfferingMessage = emptyOfferingMessage
        self.legalLinks = legalLinks
        self.palette = palette
    }
}

// MARK: - SubscriptionPaywallTheme

/// Colors for the built-in custom SwiftUI paywall.
public struct SubscriptionPaywallTheme: Equatable {
    public var accentColor: Color
    public var backgroundColor: Color
    public var foregroundColor: Color
    public var secondaryForegroundColor: Color

    public init(
        accentColor: Color,
        backgroundColor: Color,
        foregroundColor: Color,
        secondaryForegroundColor: Color
    ) {
        self.accentColor = accentColor
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.secondaryForegroundColor = secondaryForegroundColor
    }

    /// System-adaptive default theme.
    public static let `default` = SubscriptionPaywallTheme(
        accentColor: .blue,
        backgroundColor: Color(.systemBackground),
        foregroundColor: Color(.label),
        secondaryForegroundColor: Color(.secondaryLabel)
    )
}

// MARK: - SubscriptionPaywallContext

/// Observable context passed into every custom paywall provider.
///
/// `SubscriptionPaywallContext` forwards live state from ``SubscriptionManager``
/// so provider-built SwiftUI views re-render automatically.
///
/// ```swift
/// struct MyPaywallView: View {
///     @ObservedObject var context: SubscriptionPaywallContext
///
///     var body: some View {
///         ForEach(context.packages) { package in
///             Button(package.localizedPrice) {
///                 Task { await context.purchase(package) }
///             }
///         }
///     }
/// }
/// ```
@MainActor
public final class SubscriptionPaywallContext: ObservableObject {
    /// The full kit configuration.
    public var configuration: SubscriptionKitConfiguration? {
        manager.configuration
    }

    /// Packages loaded from RevenueCat, sorted by `productOrder`.
    @Published public private(set) var packages: [SubscriptionPackage] = []
    /// Current premium state.
    @Published public private(set) var state: PremiumState = .unknown
    /// `true` while a purchase is in progress.
    @Published public private(set) var isPurchasing: Bool = false
    /// `true` while a restore is in progress.
    @Published public private(set) var isRestoring: Bool = false
    /// The last purchase or restore error, if any.
    @Published public private(set) var lastError: Error?

    /// The currently selected package.
    @Published public private(set) var selectedPackage: SubscriptionPackage?

    /// `true` when state is `.premium` or `.premiumFromSnapshot`.
    public var isPremium: Bool { manager.isPremium }

    @Injected private var manager: SubscriptionManager
    private let dismissAction: () -> Void
    private var cancellables: Set<AnyCancellable> = []

    public init(
        dismiss: @escaping () -> Void
    ) {
        self.dismissAction = dismiss

        manager.$packages
            .sink { [weak self] newPackages in
                self?.packages = newPackages
                if self?.selectedPackage == nil || !newPackages.contains(where: { $0.id == self?.selectedPackage?.id }) {
                    self?.selectedPackage = newPackages.first
                }
            }
            .store(in: &cancellables)
        manager.$state
            .assign(to: \.state, on: self)
            .store(in: &cancellables)
        manager.$isPurchasing
            .assign(to: \.isPurchasing, on: self)
            .store(in: &cancellables)
        manager.$isRestoring
            .assign(to: \.isRestoring, on: self)
            .store(in: &cancellables)
        manager.$lastError
            .assign(to: \.lastError, on: self)
            .store(in: &cancellables)
    }

    /// Purchases the given package and dismisses the paywall if premium is unlocked.
    public func purchase(_ package: SubscriptionPackage) async {
        await manager.purchase(package: package)
        if manager.isPremium {
            dismissAction()
        }
    }

    /// Selects the given package.
    public func selectPackage(_ package: SubscriptionPackage) {
        selectedPackage = package
    }

    /// Restores purchases and dismisses the paywall if premium is unlocked.
    public func restorePurchases() async {
        await manager.restorePurchases()
        if manager.isPremium {
            dismissAction()
        }
    }

    /// Dismisses the paywall immediately without purchasing.
    public func dismiss() {
        dismissAction()
    }
}

// MARK: - SubscriptionCustomPaywallProviding

/// Conform to this protocol to supply a fully custom SwiftUI paywall.
///
/// The conforming type can carry its own model, state, and dependencies — decoupled
/// from the subscription machinery, which arrives via ``SubscriptionPaywallContext``.
///
/// ```swift
/// struct MyPaywall: SubscriptionCustomPaywallProviding {
///     let title: String
///
///     func makePaywall(context: SubscriptionPaywallContext) -> some View {
///         MyPaywallView(title: title, context: context)
///     }
/// }
///
/// // Use it:
/// SubscriptionKitConfiguration(
///     publicAPIKey: "appl_xxx",
///     paywallMode: .custom(provider: MyPaywall(title: "Go Pro"))
/// )
/// ```
@MainActor
public protocol SubscriptionCustomPaywallProviding {
    associatedtype Body: View

    @ViewBuilder
    func makePaywall(context: SubscriptionPaywallContext) -> Body
}

// MARK: - AnySubscriptionCustomPaywallProvider

/// Type-eraser that lets `PaywallMode.customProvider` store any
/// `SubscriptionCustomPaywallProviding` without making the configuration generic.
public struct AnySubscriptionCustomPaywallProvider {
    private let _makePaywall: @MainActor (SubscriptionPaywallContext) -> AnyView

    @MainActor
    public init<P: SubscriptionCustomPaywallProviding>(_ provider: P) {
        _makePaywall = { context in
            AnyView(provider.makePaywall(context: context))
        }
    }

    @MainActor
    public func makePaywall(context: SubscriptionPaywallContext) -> AnyView {
        _makePaywall(context)
    }
}
