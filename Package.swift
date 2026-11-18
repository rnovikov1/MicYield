// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AutoPause",
    platforms: [.macOS("14.2")],
    products: [
        .executable(name: "AutoPause", targets: ["AutoPause"]),
        .executable(name: "AutoPauseDiagnostics", targets: ["AutoPauseDiagnostics"])
    ],
    targets: [
        .target(name: "AutoPauseCore"),
        .target(name: "AutoPausePlatform", dependencies: ["AutoPauseCore"]),
        .executableTarget(name: "AutoPause", dependencies: ["AutoPauseCore", "AutoPausePlatform"]),
        .executableTarget(name: "AutoPauseDiagnostics", dependencies: ["AutoPauseCore", "AutoPausePlatform"]),
        .executableTarget(name: "AutoPauseTests", dependencies: ["AutoPauseCore", "AutoPausePlatform"], path: "Tests/AutoPauseCoreTests")
    ],
    swiftLanguageModes: [.v6]
)
