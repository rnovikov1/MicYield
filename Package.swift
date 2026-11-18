// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MicYield",
    platforms: [.macOS("14.2")],
    products: [
        .executable(name: "MicYield", targets: ["MicYield"]),
        .executable(name: "MicYieldDiagnostics", targets: ["MicYieldDiagnostics"])
    ],
    targets: [
        .target(name: "MicYieldCore"),
        .target(name: "MicYieldPlatform", dependencies: ["MicYieldCore"]),
        .executableTarget(name: "MicYield", dependencies: ["MicYieldCore", "MicYieldPlatform"]),
        .executableTarget(name: "MicYieldDiagnostics", dependencies: ["MicYieldCore", "MicYieldPlatform"]),
        .executableTarget(name: "MicYieldTests", dependencies: ["MicYieldCore", "MicYieldPlatform"], path: "Tests/MicYieldCoreTests")
    ],
    swiftLanguageModes: [.v6]
)
