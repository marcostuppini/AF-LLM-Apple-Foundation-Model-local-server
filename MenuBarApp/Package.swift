// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MenuBarApp",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MenuBarApp", targets: ["MenuBarApp"])
    ],
    targets: [
        .target(name: "MenuBarApp")
    ]
)
