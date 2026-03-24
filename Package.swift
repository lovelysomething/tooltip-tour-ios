// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TooltipTour",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "TooltipTour", targets: ["TooltipTour"]),
    ],
    targets: [
        .target(
            name: "TooltipTour",
            path: "Sources/TooltipTour"
        ),
        .testTarget(
            name: "TooltipTourTests",
            dependencies: ["TooltipTour"],
            path: "Tests/TooltipTourTests"
        ),
    ]
)
