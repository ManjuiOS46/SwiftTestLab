//
//  ManifestParsingTests.swift
//  SwiftTestLab
//
//  Created by Manju on 18/09/2026.
//

import Foundation
import Testing
@testable import SwiftTestLabKit

@Suite struct ManifestParsingTests {
    private let manifest = """
    // swift-tools-version: 6.0
    import PackageDescription

    let package = Package(
        name: "Widgets",
        products: [.library(name: "Widgets", targets: ["Widgets"])],
        targets: [
            .target(name: "Widgets"),
            .testTarget(name: "WidgetsTests", dependencies: ["Widgets"]),
        ]
    )
    """

    @Test func readsPackageNameRatherThanTheFirstNameInTheFile() {
        #expect(PackageInspector.packageName(in: manifest) == "Widgets")
    }

    @Test func readsTheTestTargetName() {
        #expect(PackageInspector.firstTestTargetName(in: manifest) == "WidgetsTests")
    }

    @Test func reportsNoTestTargetWhenThereIsNone() {
        let withoutTests = manifest.replacingOccurrences(
            of: #".testTarget(name: "WidgetsTests", dependencies: ["Widgets"]),"#,
            with: ""
        )
        #expect(PackageInspector.firstTestTargetName(in: withoutTests) == nil)
    }

    @Test func readsTheToolsVersion() {
        #expect(PackageInspector.toolsVersionMajor(in: manifest) == 6)
        #expect(PackageInspector.toolsVersionMajor(in: "// swift-tools-version:5.9\n") == 5)
    }

    @Test func moduleIsTheDirectoryUnderSources() {
        #expect(
            PackageInspector.moduleName(
                forRelativePath: "Sources/Widgets/Slider.swift",
                packageName: "Widgets"
            ) == "Widgets"
        )
        #expect(
            PackageInspector.moduleName(
                forRelativePath: "Sources/Core/Nested/Deep.swift",
                packageName: "Widgets"
            ) == "Core"
        )
    }

    @Test func aFileDirectlyInSourcesBelongsToThePackageModule() {
        #expect(
            PackageInspector.moduleName(
                forRelativePath: "Sources/Slider.swift",
                packageName: "Widgets"
            ) == "Widgets"
        )
    }
}
