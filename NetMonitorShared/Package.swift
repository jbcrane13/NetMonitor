// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NetMonitorShared",
    platforms: [
        .macOS(.v15),
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "NetMonitorShared",
            targets: ["NetMonitorShared"]
        )
    ],
    targets: [
        .target(
            name: "NetMonitorShared",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "NetMonitorSharedTests",
            dependencies: ["NetMonitorShared"]
        )
    ]
)
