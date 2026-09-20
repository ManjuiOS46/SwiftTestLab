//
//  FailedElsewhereTests.swift
//  SwiftTestLab
//
//  Created by Manju on 18/09/2026.
//

import Foundation
import Testing
@testable import SwiftTestLabKit

/// A package whose own tests already fail to compile makes every verification
/// fail. Blaming the generated test for that would be wrong, and would send the
/// user looking in the wrong file.
@Suite struct FailedElsewhereTests {
    private func report(buildLog: String) -> VerificationReport {
        VerificationReport(
            outcome: .compileFailed,
            buildLog: buildLog,
            testLog: "",
            testFileName: "ModelsTests.swift"
        )
    }

    @Test func blamesThePackageWhenNoErrorIsInTheGeneratedFile() {
        let subject = report(buildLog: """
        /tmp/p/Tests/T/BrandManagerViewTests.swift:6:20: error: cannot find type 'EngineClientProtocol' in scope
        /tmp/p/Tests/T/BrandManagerViewTests.swift:9:5: error: cannot find 'Brand' in scope
        """)

        #expect(subject.failedElsewhere)
        #expect(subject.otherFailingFiles == ["BrandManagerViewTests.swift"])
        #expect(subject.headline == "Your package doesn't compile")
        #expect(subject.detail.contains("BrandManagerViewTests.swift"))
        #expect(subject.detail.contains("not because of the generated test"))
    }

    @Test func blamesTheGeneratedTestWhenTheErrorIsInIt() {
        let subject = report(buildLog: """
        /tmp/p/Tests/T/ModelsTests.swift:12:9: error: cannot find 'Widget' in scope
        """)

        #expect(!subject.failedElsewhere)
        #expect(subject.headline == "Did not compile")
    }

    @Test func aMixtureIsStillTheGeneratedTestsProblem() {
        let subject = report(buildLog: """
        /tmp/p/Tests/T/BrandManagerViewTests.swift:6:20: error: cannot find type 'X' in scope
        /tmp/p/Tests/T/ModelsTests.swift:12:9: error: cannot find 'Widget' in scope
        """)

        #expect(!subject.failedElsewhere)
    }

    @Test func aPassingRunIsNeverBlamedOnAnyone() {
        let passing = VerificationReport(
            outcome: .passed,
            buildLog: "",
            testLog: "",
            testFileName: "ModelsTests.swift"
        )
        #expect(!passing.failedElsewhere)
    }
}

/// Swift Testing is macros, so a diagnostic inside `#expect` is reported against
/// the expansion buffer. Without mapping it back, those never reached the user.
@Suite struct MacroDiagnosticTests {
    private let log = """
    [70 / 76] BreweryTests-product
    macro expansion #expect:1:61: warning: no calls to throwing functions occur within 'try' expression [#UnnecessaryEffectMarker]
    `- /tmp/Brewery/Tests/BreweryTests/BrewerTests.swift:10:64: note: expanded code originates here
     9 |     @Test func announcingDoesNotThrow() {
    10 |         #expect(throws: Never.self) { try Brewer().announce() }
    """

    @Test func mapsAMacroDiagnosticBackToTheRealFileAndLine() {
        let found = DiagnosticParser.diagnostics(in: log)
        #expect(found.count == 1)
        #expect(found.first?.file == "BrewerTests.swift")
        #expect(found.first?.line == 10)
        #expect(found.first?.severity == .warning)
        #expect(found.first?.message.contains("no calls to throwing functions") == true)
    }

    @Test func ignoresAMacroDiagnosticWithNoOriginNote() {
        let orphan = """
        macro expansion #expect:1:61: warning: no calls to throwing functions occur within 'try' expression
        [71 / 76] Compiling something
        """
        #expect(DiagnosticParser.diagnostics(in: orphan).isEmpty)
    }

    @Test func ordinaryDiagnosticsStillParse() {
        let plain = "/tmp/p/Tests/T/ModelsTests.swift:12:9: error: cannot find 'Widget' in scope"
        let found = DiagnosticParser.diagnostics(in: plain)
        #expect(found.count == 1)
        #expect(found.first?.file == "ModelsTests.swift")
        #expect(found.first?.severity == .error)
    }
}
