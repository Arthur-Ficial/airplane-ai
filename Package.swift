// swift-tools-version: 6.0
// llama.cpp is linked from vendored dylibs at Vendor/llama.cpp/llama-b8763
// (release b8763, SHA ff5ef8278615a2462b79b50abdf3cc95cfb31c6f).
// Dylibs are embedded into AirplaneAI.app/Contents/Frameworks by scripts/build-app.sh.

import PackageDescription
import Foundation

let packageRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let vendorDylibsDir = packageRoot.appendingPathComponent("Vendor/llama.cpp/llama-b8763").path

let package = Package(
    name: "AirplaneAI",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "AirplaneAI", targets: ["AirplaneAI"]),
        .executable(name: "AirplaneIconRender", targets: ["AirplaneIconRender"]),
    ],
    targets: [
        .target(
            name: "CLlama",
            path: "Sources/CLlama",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-L", vendorDylibsDir,
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks",
                    // Dev rpath so `swift test` and `swift run` find the dylibs without bundling.
                    "-Xlinker", "-rpath",
                    "-Xlinker", vendorDylibsDir,
                ]),
                .linkedLibrary("llama"),
                .linkedLibrary("ggml"),
                .linkedLibrary("ggml-base"),
                .linkedLibrary("ggml-cpu"),
                .linkedLibrary("ggml-metal"),
            ]
        ),
        .executableTarget(
            name: "AirplaneAI",
            dependencies: ["CLlama"],
            path: "Sources/AirplaneAI",
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency"),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "./Info.plist",
                ]),
            ]
        ),
        .testTarget(
            name: "AirplaneAITests",
            dependencies: ["AirplaneAI"],
            path: "Tests"
        ),
        .executableTarget(
            name: "AirplaneIconRender",
            path: "Tools/iconrender"
        ),
    ]
)
