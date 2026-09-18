//
//  VerificationReportTests.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import Foundation
import Testing
@testable import SwiftTestLabKit

@Suite struct VerificationReportTests {
    @Test(arguments: [
        (VerificationOutcome.passed, true),
        (.testsFailed, true),
        (.noTestsRan, true),
        (.compileFailed, false),
        (.timedOut(stage: "build"), false),
        (.timedOut(stage: "test run"), true),
    ])
    func compiledReflectsHowFarItGot(outcome: VerificationOutcome, compiled: Bool) {
        let report = VerificationReport(outcome: outcome, buildLog: "", testLog: "")
        #expect(report.compiled == compiled)
    }

    @Test func onlyAPassIsAPass() {
        #expect(VerificationReport(outcome: .passed, buildLog: "", testLog: "").passed)
        #expect(!VerificationReport(outcome: .testsFailed, buildLog: "", testLog: "").passed)
    }

    @Test func recognisesAFilterThatMatchedNothing() {
        #expect(TestVerifier.matchedNothing("error: no tests found matching the filter"))
        #expect(TestVerifier.matchedNothing("No matching test cases were run"))
        #expect(!TestVerifier.matchedNothing("Test Suite 'SliderTests' passed"))
    }
}
