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
        // The Metal source links into this target's own resource bundle, which is what gives the
        // module a `Bundle.module` to load the shader library from. Declaring it also stops SwiftPM
        // warning about an unhandled file.
        .target(
            name: "SlideToConfirm",
            path: "Sources/SlideToConfirm",
            resources: [.process("SlideWake.metal")]
        ),
        .testTarget(
            name: "SlideToConfirmTests",
            dependencies: ["SlideToConfirm"],
            path: "Tests/SlideToConfirmTests"
        )
    ]
)
