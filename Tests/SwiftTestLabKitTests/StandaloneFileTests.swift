//
//  StandaloneFileTests.swift
//  SwiftTestLab
//
//  Created by Manju on 18/09/2026.
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
        try fixture.write("Sources/Widgets/Slider.swift", "struct Slider {}")
        let subject = TestSubject.standalone(
            try StandaloneFile(url: fixture.root.appending(path: "Sources/Widgets/Slider.swift"))
        )

        #expect(subject.destination(forTestFileNamed: "SliderTests.swift") == nil)
        #expect(subject.moduleName == "Widgets")
        #expect(subject.framework == .swiftTesting)
        withExtendedLifetime(fixture) {}
    }

    @Test func theStandalonePromptTellsTheModelItIsOnItsOwn() throws {
        let fixture = try Fixture()
        try fixture.write("Sources/Widgets/Slider.swift", "struct Slider {}")
        let subject = TestSubject.standalone(
            try StandaloneFile(url: fixture.root.appending(path: "Sources/Widgets/Slider.swift"))
        )

        let message = PromptBuilder.userMessage(for: subject, source: "struct Slider {}")
        #expect(message.contains("@testable import Widgets"))
        #expect(message.contains("no access to the rest of the project"))
        withExtendedLifetime(fixture) {}
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

    /// An Xcode project has no Sources directory; its module is the target, which
    /// for the common single-target app is the project's own name.
    @Test func takesTheModuleNameFromAnXcodeProject() throws {
        let fixture = try Fixture()
        try fixture.makeDirectory("LoginApp/LoginApp.xcodeproj")
        try fixture.write("LoginApp/LoginApp/HomeView.swift", "struct HomeView {}")
        let file = try StandaloneFile(
            url: fixture.root.appending(path: "LoginApp/LoginApp/HomeView.swift")
        )

        #expect(file.moduleName == "LoginApp")
        withExtendedLifetime(fixture) {}
    }

    @Test func fallsBackToTheEnclosingFolderWhenThereIsNothingElse() throws {
        let fixture = try Fixture()
        try fixture.write("Helpers/Formatting.swift", "struct Formatting {}")
        let file = try StandaloneFile(
            url: fixture.root.appending(path: "Helpers/Formatting.swift")
        )

        #expect(file.moduleName == "Helpers")
        withExtendedLifetime(fixture) {}
    }

    @Test func aPackageLayoutStillWinsOverAnXcodeProjectAlongside() throws {
        let fixture = try Fixture()
        try fixture.makeDirectory("Demo.xcodeproj")
        try fixture.write("Sources/Engine/Widget.swift", "struct Widget {}")
        let file = try StandaloneFile(
            url: fixture.root.appending(path: "Sources/Engine/Widget.swift")
        )

        #expect(file.moduleName == "Engine")
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
