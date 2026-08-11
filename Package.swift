// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SlideToConfirm",
    // macOS is declared so `swift test` can run the pure state and geometry suites on the host,
    // without a simulator. The control itself is built and shipped for iOS.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SlideToConfirm", targets: ["SlideToConfirm"])
    ],
    targets: [
        .target(name: "SlideToConfirm", path: "Sources/SlideToConfirm"),
        .testTarget(
            name: "SlideToConfirmTests",
            dependencies: ["SlideToConfirm"],
            path: "Tests/SlideToConfirmTests"
        )
    ]
)
