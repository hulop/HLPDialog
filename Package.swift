// swift-tools-version:5.4
import PackageDescription

let package = Package(
    name: "HLPDialog",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(name: "HLPDialog", targets: ["HLPDialog"])
    ],
    dependencies: [
        .package(name: "WatsonDeveloperCloud", url: "https://github.com/watson-developer-cloud/swift-sdk", from: "1.4.0"),
        .package(name: "IBMWatsonRestKit", url: "https://github.com/watson-developer-cloud/restkit.git", from: "2.0.0")
    ],
    targets: [
        .target(
            name: "HLPDialog",
            dependencies: [.product(name: "AssistantV1", package: "WatsonDeveloperCloud"),
                           .product(name: "RestKit", package: "IBMWatsonRestKit")],
            resources: [
                .process("icons.xcassets")
            ]
        ),
        .testTarget(
            name: "HLPDialogTest",
            dependencies: ["HLPDialog"]),
    ]
)
