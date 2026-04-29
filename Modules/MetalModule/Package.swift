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
        .package(path: "../BaseModule")
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
                .process("Models/planets.json")
            ]
        ),
        .testTarget(
            name: "MetalModuleTests",
            dependencies: ["MetalModule"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
