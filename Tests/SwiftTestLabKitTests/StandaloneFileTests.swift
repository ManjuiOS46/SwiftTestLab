//
//  StandaloneFileTests.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import Foundation
import Testing
@testable import SwiftTestLabKit

@Suite struct StandaloneFileTests {
    @Test func acceptsAnOrdinarySwiftFile() throws {
        let fixture = try Fixture()
        try fixture.write("Slider.swift", "struct Slider {}")

        let file = try StandaloneFile(url: fixture.root.appending(path: "Slider.swift"))
        #expect(file.baseName == "Slider")
        #expect(file.fileName == "Slider.swift")
    }

    @Test func rejectsFilesThatArentSwift() throws {
        let fixture = try Fixture()
        try fixture.write("notes.md", "# hello")

        #expect(throws: FileSelectionError.notASwiftFile(name: "notes.md")) {
            try StandaloneFile(url: fixture.root.appending(path: "notes.md"))
        }
    }

    @Test func rejectsAFileThatIsAlreadyATest() throws {
        let fixture = try Fixture()
        try fixture.write("SliderTests.swift", "import Testing")

        #expect(throws: FileSelectionError.looksLikeATestFile(name: "SliderTests.swift")) {
            try StandaloneFile(url: fixture.root.appending(path: "SliderTests.swift"))
        }
    }

    @Test func aStandaloneSubjectHasNowhereToWriteWithoutAsking() throws {
        let fixture = try Fixture()
        try fixture.write("Slider.swift", "struct Slider {}")
        let subject = TestSubject.standalone(
            try StandaloneFile(url: fixture.root.appending(path: "Slider.swift"))
        )

        #expect(subject.destination(forTestFileNamed: "SliderTests.swift") == nil)
        #expect(subject.moduleName == StandaloneFile.fallbackModuleName)
        #expect(subject.framework == .swiftTesting)
    }

    @Test func theStandalonePromptTellsTheModelItIsOnItsOwn() throws {
        let fixture = try Fixture()
        try fixture.write("Slider.swift", "struct Slider {}")
        let subject = TestSubject.standalone(
            try StandaloneFile(url: fixture.root.appending(path: "Slider.swift"))
        )

        let message = PromptBuilder.userMessage(for: subject, source: "struct Slider {}")
        #expect(message.contains("@testable import \(StandaloneFile.fallbackModuleName)"))
        #expect(message.contains("no access to the rest of the project"))
    }
}

/// A generated test is no use if it imports a module that only existed inside a
/// scratch directory. The module name has to be the one in the user's project.
@Suite struct StandaloneModuleNameTests {
    @Test func takesTheModuleNameFromTheSourcesDirectory() throws {
        let fixture = try Fixture()
        try fixture.write("Sources/PixiiCloneApp/Models.swift", "struct Brand {}")
        let file = try StandaloneFile(
            url: fixture.root.appending(path: "Sources/PixiiCloneApp/Models.swift")
        )

        #expect(file.moduleName == "PixiiCloneApp")
        #expect(file.testTargetName == "PixiiCloneAppTests")
        withExtendedLifetime(fixture) {}
    }

    @Test func thePromptAsksForThatModule() throws {
        let fixture = try Fixture()
        try fixture.write("Sources/PixiiCloneApp/Models.swift", "struct Brand {}")
        let subject = TestSubject.standalone(
            try StandaloneFile(url: fixture.root.appending(path: "Sources/PixiiCloneApp/Models.swift"))
        )

        let message = PromptBuilder.userMessage(for: subject, source: "struct Brand {}")
        #expect(message.contains("@testable import PixiiCloneApp"))
        #expect(!message.contains("import Subject"))
        withExtendedLifetime(fixture) {}
    }

    @Test func fallsBackWhenThereIsNoSourcesDirectoryToLearnFrom() throws {
        let fixture = try Fixture()
        try fixture.write("Models.swift", "struct Brand {}")
        let file = try StandaloneFile(url: fixture.root.appending(path: "Models.swift"))

        #expect(file.moduleName == StandaloneFile.fallbackModuleName)
        withExtendedLifetime(fixture) {}
    }

    @Test(arguments: [
        ("My-App", "MyApp"),
        ("app_core", "app_core"),
        ("2Fast", nil),
        ("...", nil),
    ])
    func moduleNamesAreValidSwiftIdentifiers(input: String, expected: String?) {
        #expect(StandaloneFile.asSwiftIdentifier(input) == expected)
    }
}
