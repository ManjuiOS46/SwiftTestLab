//
//  TestCodeExtractorTests.swift
//  SwiftTestLab
//
//  Created by Manju on 18/09/2026.
//

import Foundation
import Testing
@testable import SwiftTestLabKit

@Suite struct TestCodeExtractorTests {
    private let subjectBaseName = "Slider"

    private let suite = """
    import Testing
    @testable import Widgets

    @Suite struct SliderTests {
        @Test func clampsToRange() { #expect(Slider(value: 2).value == 1) }
    }
    """

    @Test func namesTheFileAfterTheSuite() throws {
        let test = try TestCodeExtractor().extract(from: suite, subjectBaseName: subjectBaseName)
        #expect(test.suiteName == "SliderTests")
        #expect(test.fileName == "SliderTests.swift")
    }

    @Test func fallsBackToTheSubjectNameWhenTheSuiteIsNamedSomethingElse() throws {
        let odd = suite.replacingOccurrences(of: "SliderTests", with: "SliderBehaviour")
        let test = try TestCodeExtractor().extract(from: odd, subjectBaseName: subjectBaseName)
        #expect(test.suiteName == "SliderBehaviour")
        #expect(test.fileName == "SliderTests.swift")
    }

    @Test func stripsMarkdownFencesTheModelWasAskedNotToSend() throws {
        let fenced = "Here you go:\n\n```swift\n\(suite)\n```\n"
        let test = try TestCodeExtractor().extract(from: fenced, subjectBaseName: subjectBaseName)
        #expect(!test.source.contains("```"))
        #expect(!test.source.contains("Here you go"))
        #expect(test.source.hasPrefix("import Testing"))
    }

    @Test func handlesXCTestSuites() throws {
        let xctest = """
        import XCTest
        @testable import Widgets

        final class SliderTests: XCTestCase {
            func testClamps() { XCTAssertEqual(Slider(value: 2).value, 1) }
        }
        """
        let test = try TestCodeExtractor().extract(from: xctest, subjectBaseName: subjectBaseName)
        #expect(test.suiteName == "SliderTests")
    }

    @Test func rejectsAReplyThatIsNotATestFile() {
        #expect(throws: ExtractionError.notATestFile) {
            try TestCodeExtractor().extract(
                from: "I can't write a test for this without more context.",
                subjectBaseName: subjectBaseName
            )
        }
    }

    @Test func rejectsATestFileWithNothingToFilterOn() {
        let noType = "import Testing\n@Test func loose() { #expect(Bool(true)) }\n"
        #expect(throws: ExtractionError.noTypeDeclaration) {
            try TestCodeExtractor().extract(from: noType, subjectBaseName: subjectBaseName)
        }
    }

    @Test func stripsTheScratchpadOpenReasoningModelsEmitInline() throws {
        let reply = """
        <think>
        I should test the clamping. Let me write a suite.
        </think>
        \(suite)
        """
        let test = try TestCodeExtractor().extract(from: reply, subjectBaseName: subjectBaseName)
        #expect(!test.source.contains("<think>"))
        #expect(!test.source.contains("I should test the clamping"))
        #expect(test.source.hasPrefix("import Testing"))
    }

    @Test func alwaysEndsTheFileWithANewline() throws {
        let test = try TestCodeExtractor().extract(from: suite, subjectBaseName: subjectBaseName)
        #expect(test.source.hasSuffix("\n"))
    }
}
