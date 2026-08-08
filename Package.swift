// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Rancage",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Rancage",
            path: "Sources",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("AppKit"),
            ]
        )
    ]
)
