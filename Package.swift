// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Plotline",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10)
    ],
    products: [
        .library(name: "Plotline", targets: ["Plotline"]),
        .library(name: "PlotlineCore", targets: ["PlotlineCore"])
    ],
    targets: [
        .target(name: "PlotlineCore"),
        .target(name: "Plotline", dependencies: ["PlotlineCore"]),
        .testTarget(name: "PlotlineCoreTests", dependencies: ["PlotlineCore"]),
        .testTarget(name: "PlotlineTests", dependencies: ["Plotline"])
    ]
)
