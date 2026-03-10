// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "VideoNotes",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "VideoNotes",
            path: "Sources/VideoNotes",
            exclude: ["Resources/Info.plist"]
        ),
        .testTarget(
            name: "VideoNotesTests",
            dependencies: ["VideoNotes"],
            path: "Tests/VideoNotesTests"
        )
    ]
)
