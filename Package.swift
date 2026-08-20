// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DsHarness",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "DsHarnessCore", targets: ["DsHarnessCore"]),
        .executable(name: "DsHarness", targets: ["DsHarnessApp"]),
        .executable(name: "DsHarnessCoreChecks", targets: ["DsHarnessCoreChecks"]),
    ],
    targets: [
        .target(name: "DsHarnessCore"),
        .executableTarget(
            name: "DsHarnessApp",
            dependencies: ["DsHarnessCore"]
        ),
        .executableTarget(
            name: "DsHarnessCoreChecks",
            dependencies: ["DsHarnessCore"]
        ),
        .testTarget(
            name: "DsHarnessCoreTests",
            dependencies: ["DsHarnessCore"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
