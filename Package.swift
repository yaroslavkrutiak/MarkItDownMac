// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MarkItDownMac",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "MarkItDownCore",
            path: ".",
            sources: [
                "Core/ShellRunner.swift",
                "Core/FileOutputManager.swift",
                "Core/SupportedFormats.swift",
                "Core/DebugLogger.swift",
                "Bridge/ConverterImplementation.swift",
                "Bridge/MarkItDownCLIImplementation.swift",
                "Bridge/ConverterBridge.swift",
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "MarkItDownTests",
            dependencies: ["MarkItDownCore"],
            path: "Tests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
