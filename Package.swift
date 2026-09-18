//
//  Package.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

// swift-tools-version: 6.0
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
        .testTarget(
            name: "SwiftTestLabKitTests",
            dependencies: ["SwiftTestLabKit"]
        ),
    ]
)
