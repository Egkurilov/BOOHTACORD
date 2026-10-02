// swift-tools-version: 5.9
import PackageDescription
import Foundation

// Flutter evaluates this manifest through ephemeral plugin symlinks. Resolve
// the real package first so the shared core remains relative to its source.
let rnnoisePackagePath = URL(fileURLWithPath: #filePath)
    .resolvingSymlinksInPath().deletingLastPathComponent()
    .appendingPathComponent("../../common/rnnoise").standardized.path

let package = Package(
    name: "flutter_webrtc",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "flutter-webrtc", targets: ["flutter_webrtc"]),
        // Lets dependent plugins (e.g. livekit_client) import WebRTC without
        // declaring a second copy of the binary target.
        .library(name: "WebRTC", targets: ["WebRTC"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(name: "BoohtaRnnoise", path: rnnoisePackagePath)
    ],
    targets: [
        .binaryTarget(
            name: "WebRTC",
            url: "https://github.com/webrtc-sdk/Specs/releases/download/150.7871.01/WebRTC.xcframework.zip",
            checksum: "03815cdf2f6a0ed328c94d74cce8fd1b8d2b6e95e2b37eab66795012fcecfdfa"
        ),
        .target(
            name: "flutter_webrtc",
            dependencies: [
                "WebRTC",
                .product(name: "BoohtaRnnoise", package: "BoohtaRnnoise"),
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            cSettings: [
                .headerSearchPath("include/flutter_webrtc")
            ],
            linkerSettings: [
                .linkedLibrary("c++")
            ]
        )
    ],
    cxxLanguageStandard: .cxx17
)
