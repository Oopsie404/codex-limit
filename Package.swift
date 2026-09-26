// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CodexLimit",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "CodexLimit", targets: ["CodexLimit"])],
    targets: [
        .executableTarget(name: "CodexLimit"),
        .testTarget(name: "CodexLimitTests", dependencies: ["CodexLimit"])
    ],
    swiftLanguageModes: [.v5]
)
