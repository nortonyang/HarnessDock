// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HarnessDock",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(name: "HarnessDockCore", targets: ["HarnessDockCore"]),
        .executable(name: "HarnessDock", targets: ["HarnessDockApp"]),
        .executable(name: "HarnessDockCoreChecks", targets: ["HarnessDockCoreChecks"]),
    ],
    targets: [
        .target(name: "HarnessDockCore"),
        .executableTarget(
            name: "HarnessDockApp",
            dependencies: ["HarnessDockCore"],
            resources: [
                .copy("Resources/Pets"),
            ]
        ),
        .executableTarget(
            name: "HarnessDockCoreChecks",
            dependencies: ["HarnessDockCore"]
        ),
        .testTarget(
            name: "HarnessDockCoreTests",
            dependencies: ["HarnessDockCore"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
