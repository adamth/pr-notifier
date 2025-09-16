// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "PRReviewLight",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "PRReviewLight",
            targets: ["PRReviewLight"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "PRReviewLight",
            dependencies: [],
            path: ".",
            sources: ["PRReviewLight.swift", "GitHubService.swift", "SettingsWindow.swift"],
            resources: []
        ),
    ]
)