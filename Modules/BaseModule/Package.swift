// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "BaseModule",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "BaseModule",
            targets: ["BaseModule"]
        ),
    ],
    dependencies: [
        .package(path: "../CommonTools"),
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.59.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "BaseModule",
            dependencies: [
                .product(name: "CommonTools", package: "CommonTools")
            ],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
            ]
        ),
        .testTarget(
            name: "BaseModuleTests",
            dependencies: ["BaseModule"],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
