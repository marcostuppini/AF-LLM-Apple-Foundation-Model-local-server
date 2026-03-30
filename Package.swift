// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AF-LLM",
    platforms: [
        .macOS(.v14) // Requires macOS Sonoma or later for Apple Intelligence
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .executable(
            name: "AF-LLM",
            targets: ["AF-LLM"]),
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.92.0"),
        // Note: FoundationModels is a system framework, not a Swift package dependency.
    ],
    targets: [
        .target(
            name: "AF-LLM",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                // FoundationModels is imported directly in code
            ]),
        .testTarget(
            name: "AF-LLMTests",
            dependencies: ["AF-LLM"],
            exclude: ["AF-LLM/main.swift"]),
    ]
)
