// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "oaaApp",
    platforms: [.macOS(.v12)],
    products: [
        .executable(name: "oaaApp", targets: ["oaaApp"])
    ],
    targets: [
        .executableTarget(
            name: "oaaApp",
            dependencies: []
        ),
        .testTarget(
            name: "oaaAppTests",
            dependencies: ["oaaApp"]),
    ]
)
