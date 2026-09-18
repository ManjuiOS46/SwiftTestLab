//
//  SwiftUISupportTests.swift
//  SwiftTestLab
//
//  Created by Manju on 18/09/2026.
//

import Foundation
import Testing
@testable import SwiftTestLabKit

/// Pins down exactly where the single-file path stops working, because "SwiftUI
/// isn't supported" is the wrong summary: it is. iOS-only API isn't, and the
/// difference is worth a test rather than a claim.
@Suite struct SwiftUISupportTests {
    @Test func platformNeutralSwiftUICompilesAndRuns() async throws {
        let fixture = try Fixture()
        try fixture.write("Badge.swift", """
        import SwiftUI

        struct Badge: View {
            let count: Int

            var label: String { count > 99 ? "99+" : String(count) }

            var body: some View {
                Text(label).foregroundStyle(count > 0 ? .primary : .secondary)
            }
        }
        """)
        let subject = TestSubject.standalone(
            try StandaloneFile(url: fixture.root.appending(path: "Badge.swift"))
        )
        let test = try TestCodeExtractor().extract(from: """
        import Testing
        @testable import \(subject.moduleName)

        @Suite struct BadgeTests {
            @Test func capsAtNinetyNinePlus() { #expect(Badge(count: 150).label == "99+") }
            @Test func showsTheCountBelowTheCap() { #expect(Badge(count: 7).label == "7") }
        }
        """, subjectBaseName: "Badge")

        let sandbox = try SandboxBuilder().make(for: subject, generatedTest: test)
        defer { SandboxBuilder().destroy(sandbox) }

        let report = try await TestVerifier().verify(sandbox: sandbox, test: test) { _ in }
        #expect(report.outcome == .passed)
        withExtendedLifetime(fixture) {}
    }

    @Test func iOSOnlyAPIDoesNotCompileAndIsWarnedAboutFirst() async throws {
        let fixture = try Fixture()
        try fixture.write("Screen.swift", """
        import SwiftUI

        struct Screen: View {
            var body: some View {
                NavigationStack { Text("hi") }
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) { Text("x") }
                    }
            }
        }
        """)
        let subject = TestSubject.standalone(
            try StandaloneFile(url: fixture.root.appending(path: "Screen.swift"))
        )

        // The user is told before spending a run on it.
        let warnings = SubjectAdvisory.warnings(for: subject, source: try subject.source())
        #expect(warnings.contains { $0.contains("iOS-only") })

        let test = try TestCodeExtractor().extract(from: """
        import Testing
        @testable import \(subject.moduleName)

        @Suite struct ScreenTests {
            @Test func builds() { _ = Screen() }
        }
        """, subjectBaseName: "Screen")

        let sandbox = try SandboxBuilder().make(for: subject, generatedTest: test)
        defer { SandboxBuilder().destroy(sandbox) }

        let report = try await TestVerifier().verify(sandbox: sandbox, test: test) { _ in }
        #expect(report.outcome == .compileFailed)
        withExtendedLifetime(fixture) {}
    }
}
