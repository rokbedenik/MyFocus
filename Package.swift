// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "MyFocus",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "MyFocus",
            path: "Sources/MyFocus"
        )
    ]
)
