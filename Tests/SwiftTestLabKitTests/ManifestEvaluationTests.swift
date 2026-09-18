//
//  ManifestEvaluationTests.swift
//  SwiftTestLab
//
//  Created by Manju on 18/09/2026.
//

import Foundation
import Testing
@testable import SwiftTestLabKit

/// Package.swift is a program, not a data file. These are the shapes that a
/// regex gets wrong and SwiftPM gets right.
@Suite struct ManifestEvaluationTests {
    /// Targets built in a loop: there is no literal `.testTarget(name: "…")`
    /// anywhere in the file, and the package name is a constant.
    @Test func findsTargetsInAManifestThatBuildsThemProgrammatically() async throws {
        let fixture = try Fixture()
        try fixture.write("Package.swift", """
        // swift-tools-version: 6.0
        import PackageDescription

        let packageName = "Engine"
        var allTargets: [Target] = []

        for module in ["Core", "Extras"] {
            allTargets.append(.target(name: module))
            allTargets.append(
                .testTarget(name: module + "Tests", dependencies: [.byName(name: module)])
            )
        }

        let package = Package(name: packageName, targets: allTargets)
        """)
        try fixture.write("Sources/Core/Engine.swift", "public struct Engine {}")
        try fixture.write("Sources/Extras/Extra.swift", "public struct Extra {}")
        try fixture.makeDirectory("Tests/CoreTests")
        try fixture.makeDirectory("Tests/ExtrasTests")

        // The textual parse — what the app used to rely on — can't see any of this.
        let manifest = try String(contentsOf: fixture.root.appending(path: "Package.swift"), encoding: .utf8)
        #expect(PackageInspector.firstTestTargetName(in: manifest) == nil)

        let package = try await PackageInspector().inspect(folder: fixture.root)
        #expect(package.name == "Engine")
        #expect(package.testTarget.name == "CoreTests")
        #expect(package.sourceFiles.map(\.moduleName).sorted() == ["Core", "Extras"])
        withExtendedLifetime(fixture) {}
    }

    @Test func honoursATestTargetThatDeclaresItsOwnPath() async throws {
        let fixture = try Fixture()
        try fixture.write("Package.swift", """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "Custom",
            targets: [
                .target(name: "Custom", path: "lib"),
                .testTarget(name: "CustomTests", dependencies: ["Custom"], path: "checks"),
            ]
        )
        """)
        try fixture.write("lib/Thing.swift", "public struct Thing {}")
        try fixture.makeDirectory("checks")

        let package = try await PackageInspector().inspect(folder: fixture.root)
        #expect(package.testTarget.relativeDirectory == "checks")
        #expect(package.sourceFiles.first?.relativePath == "lib/Thing.swift")
        #expect(package.sourceFiles.first?.moduleName == "Custom")
        withExtendedLifetime(fixture) {}
    }

    @Test func aMonorepoIsToldWhichPackagesItContains() async throws {
        let fixture = try Fixture()
        try fixture.write("Package.swift", """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(name: "Umbrella", targets: [.target(name: "Umbrella")])
        """)
        try fixture.write("Sources/Umbrella/Umbrella.swift", "public struct Umbrella {}")
        try fixture.write("Alpha/Package.swift", "// swift-tools-version: 6.0")
        try fixture.write("Beta/Package.swift", "// swift-tools-version: 6.0")

        await #expect(
            throws: PackageInspectionError.noTestTarget(
                packageName: "Umbrella",
                nestedPackages: ["Alpha", "Beta"]
            )
        ) {
            try await PackageInspector().inspect(folder: fixture.root)
        }
        withExtendedLifetime(fixture) {}
    }

    @Test func aBrokenManifestSaysSoInsteadOfClaimingThereAreNoTests() async throws {
        let fixture = try Fixture()
        try fixture.write("Package.swift", """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(name: "Broken", targets: [.target(name: "Nope"
        """)
        try fixture.write("Sources/Nope/Nope.swift", "public struct Nope {}")

        var reported: String?
        do {
            _ = try await PackageInspector().inspect(folder: fixture.root)
        } catch let error as PackageInspectionError {
            if case .manifestRejected(let reason) = error { reported = reason }
        }
        #expect(reported != nil)
        withExtendedLifetime(fixture) {}
    }
}
