// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "R3VIB3",
    platforms: [
        .macOS(.v12),
    ],
    targets: [
        .executableTarget(
            name: "R3VIB3",
            path: "LocalTranscribePaste",
            exclude: [
                "Resources/Info.plist",
                "LocalTranscribePaste.entitlements",
            ],
            resources: [
                .process("Resources"),
            ])
    ]
)
