// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CoolAlert",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "CoolAlert", targets: ["CoolAlert"])
    ],
    targets: [
        .target(name: "CoolAlert"),
        .testTarget(name: "CoolAlertTests", dependencies: ["CoolAlert"])
    ]
)
