// swift-tools-version:5.9
import Foundation
import PackageDescription

// **The tuning panel is opt-OUT — present unless explicitly removed**, as in
// Skid Jam. TestFlight builds are release builds, and tuning on a real device
// is what they are for, so gating the panel behind DEBUG or an opt-in flag
// would remove it from exactly the builds that need it. The production release
// removes it:
//
//     QUACK_NO_TUNING=1 make test      (tests the compiled-out path)
//     QUACK_NO_TUNING=1 make release   (the store build)
let tuning = ProcessInfo.processInfo.environment["QUACK_NO_TUNING"] != "1"
let featureFlagSettings: [SwiftSetting] = tuning ? [.define("QUACK_TUNING")] : []

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
            resources: [.process("Resources/Localizable.xcstrings")],
            swiftSettings: featureFlagSettings
        ),
        .testTarget(name: "QuackCoreTests", dependencies: ["QuackCore"]),
    ]
)
