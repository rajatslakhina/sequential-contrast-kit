// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "SequentialContrastKit",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9)
    ],
    products: [
        .library(name: "SequentialContrastKit", targets: ["SequentialContrastKit"]),
        .executable(name: "SequentialContrastDemo", targets: ["SequentialContrastDemo"])
    ],
    targets: [
        .target(
            name: "SequentialContrastKit",
            swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
        ),
        .executableTarget(
            name: "SequentialContrastDemo",
            dependencies: ["SequentialContrastKit"],
            swiftSettings: [.enableUpcomingFeature("StrictConcurrency")]
        ),
        .testTarget(
            name: "SequentialContrastKitTests",
            dependencies: ["SequentialContrastKit"]
        )
    ]
)
