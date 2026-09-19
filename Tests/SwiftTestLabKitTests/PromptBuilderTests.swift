//
//  PromptBuilderTests.swift
//  SwiftTestLab
//
//  Created by Manju on 19/09/2026.
//

import Foundation
import Testing
@testable import SwiftTestLabKit

@Suite struct ImportScanningTests {
    @Test func readsPlainImports() {
        let modules = PromptBuilder.importedModules(in: """
        import Foundation
        import AppKit

        struct Thing {}
        """)
        #expect(modules == ["Foundation", "AppKit"])
    }

    @Test func takesTheModuleFromAMemberImport() {
        #expect(PromptBuilder.importedModules(in: "import struct Foundation.Data") == ["Foundation"])
    }

    @Test func seesPastAnAttribute() {
        #expect(PromptBuilder.importedModules(in: "@preconcurrency import AppKit") == ["AppKit"])
    }

    @Test func doesNotMistakeAModuleNamedAfterAKeywordForAMemberImport() {
        #expect(PromptBuilder.importedModules(in: "import classKit") == ["classKit"])
    }

    @Test func ignoresTheWordImportInsideCode() {
        #expect(PromptBuilder.importedModules(in: "let importer = Importer()").isEmpty)
    }

    @Test func listsEachModuleOnce() {
        #expect(PromptBuilder.importedModules(in: "import A\nimport B\nimport A") == ["A", "B"])
    }
}

@Suite struct GlobalActorDetectionTests {
    @Test func findsAnActorOnTheDeclaration() {
        #expect(PromptBuilder.globalActor(in: "@MainActor\nfinal class Model {}") == "MainActor")
    }

    @Test func findsOneWrittenOnTheSameLine() {
        #expect(PromptBuilder.globalActor(in: "@MainActor final class Model {}") == "MainActor")
    }

    @Test func findsACustomGlobalActor() {
        #expect(PromptBuilder.globalActor(in: "@DatabaseActor\nstruct Store {}") == "DatabaseActor")
    }

    @Test func ignoresAnAttributeOnANestedMember() {
        // Indented, so it belongs to a member — the type itself is nonisolated and
        // a test can construct it without isolation of its own.
        #expect(PromptBuilder.globalActor(in: "struct Model {\n    @MainActor var x = 0\n}") == nil)
    }

    @Test func saysNothingAboutAnOrdinaryFile() {
        #expect(PromptBuilder.globalActor(in: "struct Pricer { func total() -> Int { 0 } }") == nil)
    }
}

@Suite struct PackageMessageTests {
    /// Two modules, the app one reaching into the kit — the shape that produced a
    /// test which couldn't see the kit's types.
    private func splitPackage() throws -> Fixture {
        let fixture = try Fixture()
        try fixture.write("Package.swift", """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "Split",
            targets: [
                .target(name: "Kit"),
                .target(name: "App", dependencies: ["Kit"]),
                .testTarget(name: "AppTests", dependencies: ["App", "Kit"]),
            ]
        )
        """)
        try fixture.write("Sources/Kit/Engine.swift", "public struct Engine {}")
        try fixture.makeDirectory("Tests/AppTests")
        return fixture
    }

    private func message(for source: String) async throws -> (Fixture, String) {
        let fixture = try splitPackage()
        try fixture.write("Sources/App/Model.swift", source)
        let package = try await PackageInspector().inspect(folder: fixture.root)
        let file = try #require(package.sourceFiles.first { $0.fileName == "Model.swift" })
        let subject = TestSubject.inPackage(package: package, file: file)
        return (fixture, PromptBuilder.userMessage(for: subject, source: source))
    }

    @Test func namesTheSiblingModuleTheTestWillAlsoNeed() async throws {
        let (fixture, message) = try await message(for: """
        import Foundation
        import Kit

        struct Model {
            let engine = Engine()
        }
        """)

        #expect(message.contains("@testable import App"))
        #expect(message.contains("`Kit`"))
        #expect(message.contains("import them in the test file as well"))
        withExtendedLifetime(fixture) {}
    }

    @Test func keepsSystemFrameworksSeparateFromPackageModules() async throws {
        let (fixture, message) = try await message(for: """
        import AppKit
        import Kit

        struct Model {}
        """)

        #expect(message.contains("`AppKit`"))
        #expect(message.contains("outside the package"))
        withExtendedLifetime(fixture) {}
    }

    @Test func asksForAnIsolatedSuiteWhenTheSubjectIsIsolated() async throws {
        let (fixture, message) = try await message(for: """
        import Foundation

        @MainActor
        final class Model {
            var count = 0
        }
        """)

        #expect(message.contains("`@MainActor`-isolated"))
        #expect(message.contains("mark the test type"))
        withExtendedLifetime(fixture) {}
    }

    @Test func staysShortWhenThereIsNothingExtraToSay() async throws {
        let (fixture, message) = try await message(for: """
        import Foundation

        struct Pricer {
            func total(of values: [Int]) -> Int { values.reduce(0, +) }
        }
        """)

        #expect(message.contains("@testable import App"))
        #expect(!message.contains("outside the package"))
        #expect(!message.contains("isolated"))
        withExtendedLifetime(fixture) {}
    }
}
