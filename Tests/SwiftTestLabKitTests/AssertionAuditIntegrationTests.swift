//
//  AssertionAuditIntegrationTests.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 20/09/2026.
//

import Foundation
import Testing
@testable import SwiftTestLabKit

/// Proves the no-throw judgement against the real compiler rather than a
/// hand-written warning: one subject with a throwing method and a non-throwing
/// one, both asserted the same way. Only the second is vacuous, and only the
/// compiler can tell you which.
@Suite struct AssertionAuditIntegrationTests {
    @Test func onlyTheNoThrowAssertionThatCannotFailIsFlagged() async throws {
        let fixture = try Fixture()
        try fixture.write("Sources/Brewery/Brewer.swift", """
        public enum BrewError: Error { case noBeans }

        public struct Brewer {
            public init() {}

            public func brew(hasBeans: Bool) throws -> String {
                guard hasBeans else { throw BrewError.noBeans }
                return "coffee"
            }

            public func announce() {}
        }
        """)
        let subject = TestSubject.standalone(
            try StandaloneFile(url: fixture.root.appending(path: "Sources/Brewery/Brewer.swift"))
        )

        let test = try TestCodeExtractor().extract(
            from: """
            import Testing
            @testable import \(subject.moduleName)

            @Suite struct BrewerTests {
                @Test func brewingWithBeansDoesNotThrow() {
                    #expect(throws: Never.self) { try Brewer().brew(hasBeans: true) }
                }

                @Test func announcingDoesNotThrow() {
                    #expect(throws: Never.self) { try Brewer().announce() }
                }
            }
            """,
            subjectBaseName: "Brewer"
        )

        let sandbox = try SandboxBuilder().make(for: subject, generatedTest: test)
        defer { SandboxBuilder().destroy(sandbox) }
        let report = try await TestVerifier().verify(sandbox: sandbox, test: test) { _ in }

        // Both assertions pass; nothing here is a test failure.
        #expect(report.outcome == .passed)

        // On the source alone, neither can be judged.
        #expect(test.vacuousAssertions.isEmpty)

        let audited = AssertionAudit.vacuousAssertions(
            in: test.source,
            confirmedBy: report.diagnostics,
            inFileNamed: report.testFileName
        )
        #expect(audited.count == 1)
        #expect(audited.first?.text.contains("announce") == true)
        withExtendedLifetime(fixture) {}
    }
}
