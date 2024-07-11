// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RestApiStore",
    dependencies: [
        .package(url: "https://github.com/tomieq/swifter", branch: "develop"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.3")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "RestApiStore",
        dependencies: [
            .product(name: "Swifter", package: "Swifter"),
            .product(name: "SQLite", package: "SQLite.swift")
        ])
    ]
)
