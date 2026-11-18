// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "OnvoiChat",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "OnvoiChat", targets: ["OnvoiChat"]),
    ],
    targets: [
        .target(name: "OnvoiChat"),
        .testTarget(name: "OnvoiChatTests", dependencies: ["OnvoiChat"]),
    ]
)
