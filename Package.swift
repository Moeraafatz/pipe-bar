// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PipeBar",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "PipeBarCore", targets: ["PipeBarCore"]),
        .library(name: "PipeBarUI", targets: ["PipeBarUI"]),
        .executable(name: "PipeBar", targets: ["PipeBar"]),
        .executable(name: "PipeBarTools", targets: ["PipeBarTools"])
    ],
    targets: [
        .target(
            name: "PipeBarCore",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
                .linkedFramework("PDFKit"),
                .linkedFramework("Vision"),
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics")
            ]
        ),
        .target(
            name: "PipeBarUI",
            dependencies: ["PipeBarCore"],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit")
            ]
        ),
        .executableTarget(
            name: "PipeBar",
            dependencies: ["PipeBarCore", "PipeBarUI"],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon")
            ]
        ),
        .executableTarget(
            name: "PipeBarTools",
            dependencies: ["PipeBarCore", "PipeBarUI"],
            linkerSettings: [
                .linkedFramework("SwiftUI"),
                .linkedFramework("AppKit"),
                .linkedFramework("CoreGraphics")
            ]
        ),
        .testTarget(
            name: "PipeBarTests",
            dependencies: ["PipeBarCore", "PipeBarUI"]
        )
    ]
)
