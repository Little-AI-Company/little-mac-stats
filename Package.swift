// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacStats",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ProcessCore", targets: ["ProcessCore"]),
        .executable(name: "MacStats", targets: ["MacStats"]),
        .executable(name: "ProcessProbe", targets: ["ProcessProbe"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"),
    ],
    targets: [
        .target(name: "ProcessCore"),
        .executableTarget(
            name: "MacStats",
            dependencies: ["ProcessCore", .product(name: "Sparkle", package: "Sparkle")],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]
        ),
        .executableTarget(name: "ProcessProbe", dependencies: ["ProcessCore"]),
        .testTarget(name: "ProcessCoreTests", dependencies: ["ProcessCore"]),
    ],
    swiftLanguageModes: [.v6]
)
