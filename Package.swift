// swift-tools-version: 6.0
// NOTE: llama.cpp has no Package.swift upstream. It is vendored in Milestone 5 as a
// cTarget pinned to llama.cpp release b8763 (SHA ff5ef8278615a2462b79b50abdf3cc95cfb31c6f).
// Until then, the foundation layer (Domain, Contracts, Safety, Persistence) builds
// and tests without the engine. This matches the spec's dependency rule: only the
// Inference layer touches llama.cpp.

import PackageDescription

let package = Package(
    name: "AirplaneAI",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "AirplaneAI", targets: ["AirplaneAI"]),
    ],
    targets: [
        .executableTarget(
            name: "AirplaneAI",
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
