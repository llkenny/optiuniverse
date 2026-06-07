// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MetalModule",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MetalModule",
            targets: ["MetalModule"]
        ),
    ],
    dependencies: [
        .package(path: "../CommonTools"),
        .package(path: "../BaseModule"),
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.59.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "MetalModule",
            dependencies: [
                .product(name: "CommonTools", package: "CommonTools"),
                .product(name: "BaseModule", package: "BaseModule")
            ],
            resources: [
                .copy("Assets/Models/high_resolution_solar_system.usdz"),
                .process("Assets/Environment"),
                .process("Models/planets.json")
            ],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
            ]
        ),
        .testTarget(
            name: "MetalModuleTests",
            dependencies: ["MetalModule"],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
