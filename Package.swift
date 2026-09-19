//
//  Package.swift
//  SwiftTestLab
//
//  Created by Manju on 18/09/2026.
//

// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SwiftTestLab",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "SwiftTestLab", targets: ["SwiftTestLab"]),
        .library(name: "SwiftTestLabKit", targets: ["SwiftTestLabKit"]),
    ],
    targets: [
        .executableTarget(
            name: "SwiftTestLab",
            dependencies: ["SwiftTestLabKit"]
        ),
        .target(name: "SwiftTestLabKit"),
        // Depends on the app target as well as the kit, so the app can be pointed
        // at itself and generate a test for any of its own files. Without this the
        // 15 files in Sources/SwiftTestLab could never produce a test that
        // compiles, and the app correctly said so on every one of them.
        .testTarget(
            name: "SwiftTestLabKitTests",
            dependencies: ["SwiftTestLabKit", "SwiftTestLab"]
        ),
    ]
)
