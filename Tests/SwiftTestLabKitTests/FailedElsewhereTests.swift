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
