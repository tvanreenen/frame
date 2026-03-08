// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FramePackage",
    // Runtime support for parameterized protocol types is only available in macOS 13.0.0 or newer
    // And it specifies deploymentTarget for CLI
    platforms: [.macOS(.v13)],
    // Products define the executables and libraries a package produces, making them visible to other packages.
    products: [
        .executable(name: "frame", targets: ["Cli"]),
        // Don't use this build for release, use xcode instead
        .executable(name: "FrameApp", targets: ["FrameApp"]),
        .library(name: "FrameEngine", targets: ["FrameEngine"]),
        .library(name: "FrameMacOS", targets: ["FrameMacOS"]),
        .library(name: "FrameUI", targets: ["FrameUI"]),
        // We only need to expose this as a product for xcode
        .library(name: "AppBundle", targets: ["AppBundle"]),
    ],
    dependencies: [
        .package(url: "https://github.com/LebJe/TOMLKit.git", exact: "0.5.5"),
        .package(url: "https://github.com/soffes/HotKey.git", exact: "0.2.1"),
    ],
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    targets: [
        // Exposes the private _AXUIElementGetWindow function to swift
        .target(
            name: "PrivateApi",
            path: "Sources/PrivateApi",
            publicHeadersPath: "include",
        ),
        .target(
            name: "Common",
            dependencies: [],
        ),
        .target(
            name: "FrameEngine",
            dependencies: [
                .target(name: "Common"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ],
        ),
        .target(
            name: "FrameUI",
            dependencies: [
                .target(name: "FrameEngine"),
                .target(name: "Common"),
            ],
        ),
        .target(
            name: "FrameMacOS",
            dependencies: [
                .product(name: "HotKey", package: "HotKey"),
                .product(name: "TOMLKit", package: "TOMLKit"),
                .target(name: "FrameEngine"),
                .target(name: "FrameUI"),
                .target(name: "Common"),
                .target(name: "PrivateApi"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ],
        ),
        .target(
            name: "AppBundle",
            dependencies: [
                .target(name: "FrameEngine"),
                .target(name: "FrameMacOS"),
                .target(name: "FrameUI"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ],
        ),
        .executableTarget(
            name: "FrameApp",
            dependencies: [
                .target(name: "AppBundle"),
            ],
        ),
        .executableTarget(
            name: "Cli",
            dependencies: [
                .target(name: "Common"),
            ],
        ),
        .target(
            name: "FrameTestSupport",
            dependencies: [
                .target(name: "FrameEngine"),
                .target(name: "FrameMacOS"),
                .target(name: "FrameUI"),
                .target(name: "Common"),
                .product(name: "HotKey", package: "HotKey"),
                .product(name: "TOMLKit", package: "TOMLKit"),
            ],
            path: "Tests/FrameTestSupport",
        ),
        .testTarget(
            name: "FrameEngineTests",
            dependencies: [
                .target(name: "FrameEngine"),
                .target(name: "FrameMacOS"),
                .target(name: "FrameUI"),
                .target(name: "FrameTestSupport"),
                .target(name: "Common"),
                .product(name: "HotKey", package: "HotKey"),
            ],
        ),
        .testTarget(
            name: "FrameMacOSTests",
            dependencies: [
                .target(name: "FrameEngine"),
                .target(name: "FrameMacOS"),
                .target(name: "FrameUI"),
                .target(name: "FrameTestSupport"),
                .target(name: "Common"),
                .product(name: "HotKey", package: "HotKey"),
                .product(name: "TOMLKit", package: "TOMLKit"),
            ],
        ),
        .testTarget(
            name: "FrameUITests",
            dependencies: [
                .target(name: "FrameUI"),
            ],
        ),
        .testTarget(
            name: "AppBundleTests",
            dependencies: [
                .target(name: "AppBundle"),
            ],
            path: "Sources/AppBundleTests",
            exclude: [
                "fixtures",
            ],
        ),
    ],
)
