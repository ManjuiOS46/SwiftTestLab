//
//  PackageInspectorTests.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import Foundation
import Testing
@testable import SwiftTestLabKit

@Suite struct PackageInspectorTests {
    @Test func rejectsAFolderWithoutAManifest() throws {
        let fixture = try Fixture()
        #expect(throws: PackageInspectionError.notASwiftPackage(fixture.root)) {
            try PackageInspector().inspect(folder: fixture.root)
        }
    }

    @Test func namesXcodeProjectsAsOutOfScopeRatherThanJustUnrecognised() throws {
        let fixture = try Fixture()
        try fixture.makeDirectory("App.xcodeproj")
        #expect(throws: PackageInspectionError.xcodeProjectUnsupported(fixture.root)) {
            try PackageInspector().inspect(folder: fixture.root)
        }
    }

    @Test func reportsAMissingTestTargetByName() throws {
        let fixture = try Fixture()
        try fixture.write("Package.swift", Fixture.manifest(includeTestTarget: false))
        try fixture.write("Sources/Widgets/Slider.swift", "struct Slider {}")

        #expect(throws: PackageInspectionError.noTestTarget(packageName: "Widgets")) {
            try PackageInspector().inspect(folder: fixture.root)
        }
    }

    @Test func listsSourcesAndSkipsExistingTests() throws {
        let fixture = try makeCompletePackage()
        let package = try PackageInspector().inspect(folder: fixture.root)

        let paths = package.sourceFiles.map(\.relativePath)
        #expect(paths.contains("Sources/Widgets/Slider.swift"))
        #expect(paths.contains("Sources/Widgets/Dial.swift"))
        #expect(!paths.contains { $0.hasSuffix("Tests.swift") })
        #expect(!paths.contains { $0.contains(".build") })
    }

    @Test func infersSwiftTestingFromTheExistingTests() throws {
        let fixture = try makeCompletePackage()
        try fixture.write("Tests/WidgetsTests/DialTests.swift", "import Testing\n")

        let package = try PackageInspector().inspect(folder: fixture.root)
        #expect(package.testTarget.framework == .swiftTesting)
        #expect(package.testTarget.relativeDirectory == "Tests/WidgetsTests")
    }

    @Test func infersXCTestFromTheExistingTests() throws {
        let fixture = try makeCompletePackage()
        try fixture.write("Tests/WidgetsTests/DialTests.swift", "import XCTest\n")

        let package = try PackageInspector().inspect(folder: fixture.root)
        #expect(package.testTarget.framework == .xctest)
    }

    @Test func fallsBackToTheToolsVersionWhenThereAreNoTestsToLearnFrom() throws {
        let fixture = try makeCompletePackage()
        let package = try PackageInspector().inspect(folder: fixture.root)
        #expect(package.testTarget.framework == .swiftTesting)
        #expect(package.testTarget.frameworkEvidence.contains("swift-tools-version"))
    }

    private func makeCompletePackage() throws -> Fixture {
        let fixture = try Fixture()
        try fixture.write("Package.swift", Fixture.manifest(includeTestTarget: true))
        try fixture.write("Sources/Widgets/Slider.swift", "struct Slider {}")
        try fixture.write("Sources/Widgets/Dial.swift", "struct Dial {}")
        try fixture.write("Sources/Widgets/SliderTests.swift", "// not a source file")
        try fixture.write(".build/checkouts/Other/Sources/Other/Thing.swift", "struct Thing {}")
        try fixture.makeDirectory("Tests/WidgetsTests")
        return fixture
    }
}

/// A throwaway directory tree, cleaned up when the test ends.
final class Fixture {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "SwiftTestLabFixture-\(UUID().uuidString)")
            .resolvingSymlinksInPath()
            .standardizedFileURL
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    func write(_ relativePath: String, _ contents: String) throws {
        let url = root.appending(path: relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    func makeDirectory(_ relativePath: String) throws {
        try FileManager.default.createDirectory(
            at: root.appending(path: relativePath),
            withIntermediateDirectories: true
        )
    }

    static func manifest(includeTestTarget: Bool) -> String {
        let testTarget = includeTestTarget
            ? #"        .testTarget(name: "WidgetsTests", dependencies: ["Widgets"]),"#
            : ""
        return """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "Widgets",
            targets: [
                .target(name: "Widgets"),
        \(testTarget)
            ]
        )
        """
    }
}
