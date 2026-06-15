// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SubscriptionKit",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "SubscriptionKit",
            targets: ["SubscriptionKit"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/RevenueCat/purchases-ios-spm.git",
            from: "5.0.0"
        )
    ],
    targets: [
        .target(
            name: "SubscriptionKit",
            dependencies: [
                .product(name: "RevenueCat", package: "purchases-ios-spm"),
                .product(name: "RevenueCatUI", package: "purchases-ios-spm")
            ],
            path: "Sources/SubscriptionKit"
        ),
        .testTarget(
            name: "SubscriptionKitTests",
            dependencies: ["SubscriptionKit"],
            path: "Tests/SubscriptionKitTests"
        )
    ]
)
