//
//  SubjectAdvisoryTests.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import Foundation
import Testing
@testable import SwiftTestLabKit

@Suite struct SubjectAdvisoryTests {
    private func standalone(_ source: String) throws -> (Fixture, TestSubject) {
        let fixture = try Fixture()
        try fixture.write("Screen.swift", source)
        return (
            fixture,
            .standalone(try StandaloneFile(url: fixture.root.appending(path: "Screen.swift")))
        )
    }

    @Test func warnsWhenALooseFileImportsUIKit() async throws {
        let (fixture, subject) = try standalone("import UIKit\nclass Screen: UIViewController {}")
        let source = try subject.source()

        let warnings = SubjectAdvisory.warnings(for: subject, source: source)
        #expect(warnings.contains { $0.contains("UIKit") && $0.contains("macOS") })
        withExtendedLifetime(fixture) {}
    }

    @Test func warnsAboutIOSOnlySwiftUIEvenWithoutAUIKitImport() async throws {
        let (fixture, subject) = try standalone("""
        import SwiftUI

        struct Screen: View {
            var body: some View {
                Text("hi").toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) { Text("x") }
                }
            }
        }
        """)
        let source = try subject.source()

        let warnings = SubjectAdvisory.warnings(for: subject, source: source)
        #expect(warnings.contains { $0.contains("iOS-only") })
        withExtendedLifetime(fixture) {}
    }

    @Test func warnsThatAViewIsAThinSubject() async throws {
        let (fixture, subject) = try standalone("""
        import SwiftUI

        struct Screen: View {
            var body: some View { Text("hi") }
        }
        """)
        let source = try subject.source()

        let warnings = SubjectAdvisory.warnings(for: subject, source: source)
        #expect(warnings.contains { $0.contains("thin test") })
        withExtendedLifetime(fixture) {}
    }

    @Test func saysNothingAboutOrdinaryLogic() async throws {
        let (fixture, subject) = try standalone("""
        struct Pricer {
            func total(of values: [Int]) -> Int { values.reduce(0, +) }
        }
        """)
        let source = try subject.source()

        #expect(SubjectAdvisory.warnings(for: subject, source: source).isEmpty)
        withExtendedLifetime(fixture) {}
    }

    @Test func aFileInsideAPackageIsNotWarnedAboutPlatformMismatch() async throws {
        let fixture = try Fixture.widgetsPackage()
        try fixture.write("Sources/Widgets/Screen.swift", "import UIKit\nclass Screen {}")
        let package = try await PackageInspector().inspect(folder: fixture.root)
        let file = try #require(package.sourceFiles.first { $0.fileName == "Screen.swift" })
        let subject = TestSubject.inPackage(package: package, file: file)

        // Its own package decides its platforms; we're not wrapping it in ours.
        let warnings = SubjectAdvisory.warnings(for: subject, source: try subject.source())
        #expect(!warnings.contains { $0.contains("macOS") })
        withExtendedLifetime(fixture) {}
    }
}
