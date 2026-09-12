// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "QuackCore",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macOS(.v14),
    ],
    products: [
        // Pure simulation — deterministic, no UI dependencies. Headlessly testable.
        .library(name: "QuackCore", targets: ["QuackCore"]),
        // SpriteKit rendering + input glue. Depends on QuackCore.
        .library(name: "QuackKit", targets: ["QuackKit"]),
    ],
    targets: [
        .target(name: "QuackCore"),
        .target(
            name: "QuackKit",
            dependencies: ["QuackCore"],
            resources: [.process("Resources/Localizable.xcstrings")]
        ),
        .testTarget(name: "QuackCoreTests", dependencies: ["QuackCore"]),
    ]
)
