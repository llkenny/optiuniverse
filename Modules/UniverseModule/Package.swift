// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "UniverseModule",
    platforms: [
        .iOS(.v26)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "UniverseModule",
            targets: ["UniverseModule"]
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
            name: "UniverseModule",
            dependencies: [
                .product(name: "CommonTools", package: "CommonTools"),
                .product(name: "BaseModule", package: "BaseModule")
            ],
            resources: [
                .copy("Assets/Models/high_resolution_solar_system.usdz"),
                .copy("Assets/Models/Sun.usdz"),
                .copy("Assets/Models/Mercury.usdz"),
                .copy("Assets/Models/Earth.usdz"),
                .copy("Assets/Models/Moon.usdz"),
                .copy("Assets/Models/Mars.usdz"),
                .copy("Assets/Models/Neptune.usdz"),
                .copy("Assets/Models/Pluto.usdz"),
                .process("Assets/Models/celestial_assets.json"),
                .process("Assets/Environment"),
                .process("Models/planets.json")
            ],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
            ]
        ),
        .testTarget(
            name: "UniverseModuleTests",
            dependencies: ["UniverseModule"],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
