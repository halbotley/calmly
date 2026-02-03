// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "calmly",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "calmly",
            path: "Sources"
        ),
    ]
)
