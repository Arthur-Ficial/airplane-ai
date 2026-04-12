// swift-tools-version: 6.0
// llama.cpp is linked from vendored dylibs at Vendor/llama.cpp/llama-b8763
// (release b8763, SHA ff5ef8278615a2462b79b50abdf3cc95cfb31c6f).
// Dylibs are embedded into AirplaneAI.app/Contents/Frameworks by scripts/build-app.sh.

import PackageDescription

let vendorDylibsDir = "./Vendor/llama.cpp/llama-b8763"

let package = Package(
    name: "AirplaneAI",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "AirplaneAI", targets: ["AirplaneAI"]),
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
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@loader_path/../Frameworks",
                    // Dev rpath so `swift test` and `swift run` find the dylibs without bundling.
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Users/franzenzenhofer/dev/airplane-ai/Vendor/llama.cpp/llama-b8763",
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
            exclude: [
                "Resources/models/airplane-model.gguf.partial",
            ],
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
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@loader_path/../Frameworks",
                ]),
            ]
        ),
        .testTarget(
            name: "AirplaneAITests",
            dependencies: ["AirplaneAI"],
            path: "Tests"
        ),
    ]
)
