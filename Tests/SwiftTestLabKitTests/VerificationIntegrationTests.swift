//
//  VerificationIntegrationTests.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import Foundation
import Testing
@testable import SwiftTestLabKit

/// These actually build and run Swift packages, so they are slower than the rest
/// of the suite. They are also the only tests that prove the central claim: that
/// a generated test is verified by compiling and running it.
@Suite struct VerificationIntegrationTests {
    @Test func aGoodTestCompilesPassesAndNeverTouchesTheRealPackage() async throws {
        let fixture = try Fixture.widgetsPackage()
        let package = try PackageInspector().inspect(folder: fixture.root)
        let subject = TestSubject.inPackage(
            package: package,
            file: try #require(package.sourceFiles.first)
        )

        let test = try TestCodeExtractor().extract(
            from: """
            import Testing
            @testable import Widgets

            @Suite struct SliderTests {
                @Test func clampsAboveTheRange() { #expect(Slider(value: 2).value == 1) }
                @Test func clampsBelowTheRange() { #expect(Slider(value: -1).value == 0) }
            }
            """,
            subjectBaseName: "Slider"
        )

        let sandbox = try SandboxBuilder().make(for: subject, generatedTest: test)
        defer { SandboxBuilder().destroy(sandbox) }

        let report = try await TestVerifier().verify(sandbox: sandbox, test: test) { _ in }

        #expect(report.outcome == .passed)
        #expect(report.compiled)
        #expect(!FileManager.default.fileExists(
            atPath: package.destination(forTestFileNamed: test.fileName).path(percentEncoded: false)
        ))
        #expect(!sandbox.isSynthesised)
        withExtendedLifetime(fixture) {}
    }

    @Test func aTestThatDoesNotCompileIsReportedAsSuch() async throws {
        let fixture = try Fixture.widgetsPackage()
        let package = try PackageInspector().inspect(folder: fixture.root)
        let subject = TestSubject.inPackage(
            package: package,
            file: try #require(package.sourceFiles.first)
        )

        let test = try TestCodeExtractor().extract(
            from: """
            import Testing
            @testable import Widgets

            @Suite struct SliderTests {
                @Test func referencesSomethingThatIsNotThere() {
                    #expect(Slider(value: 2).noSuchProperty == 1)
                }
            }
            """,
            subjectBaseName: "Slider"
        )

        let sandbox = try SandboxBuilder().make(for: subject, generatedTest: test)
        defer { SandboxBuilder().destroy(sandbox) }

        let report = try await TestVerifier().verify(sandbox: sandbox, test: test) { _ in }

        #expect(report.outcome == .compileFailed)
        #expect(!report.compiled)
        #expect(report.buildLog.contains("error:"))
        withExtendedLifetime(fixture) {}
    }

    @Test func alooseFileIsWrappedInAPackageAndActuallyRuns() async throws {
        let fixture = try Fixture()
        try fixture.write("Temperature.swift", """
        public struct Temperature {
            public let celsius: Double

            public init(celsius: Double) { self.celsius = celsius }

            public var fahrenheit: Double { celsius * 9 / 5 + 32 }
        }
        """)
        let subject = TestSubject.standalone(
            try StandaloneFile(url: fixture.root.appending(path: "Temperature.swift"))
        )

        let test = try TestCodeExtractor().extract(
            from: """
            import Testing
            @testable import Subject

            @Suite struct TemperatureTests {
                @Test func freezingConverts() {
                    #expect(Temperature(celsius: 0).fahrenheit == 32)
                }

                @Test func conversionIsMonotonic() {
                    #expect(Temperature(celsius: 10).fahrenheit > Temperature(celsius: 0).fahrenheit)
                }
            }
            """,
            subjectBaseName: "Temperature"
        )

        let sandbox = try SandboxBuilder().make(for: subject, generatedTest: test)
        defer { SandboxBuilder().destroy(sandbox) }

        #expect(sandbox.isSynthesised)

        let report = try await TestVerifier().verify(sandbox: sandbox, test: test) { _ in }
        #expect(report.outcome == .passed)

        // The user's directory gets nothing; standalone mode saves only on request.
        let siblings = try FileManager.default.contentsOfDirectory(
            atPath: fixture.root.path(percentEncoded: false)
        )
        #expect(siblings == ["Temperature.swift"])
        withExtendedLifetime(fixture) {}
    }

    @Test func cancellingLeavesNoProcessRunningAndNothingOnDisk() async throws {
        let fixture = try Fixture.widgetsPackage()
        let package = try PackageInspector().inspect(folder: fixture.root)
        let subject = TestSubject.inPackage(
            package: package,
            file: try #require(package.sourceFiles.first)
        )

        let test = try TestCodeExtractor().extract(
            from: """
            import Testing
            @testable import Widgets
            @Suite struct SliderTests {
                @Test func clamps() { #expect(Slider(value: 2).value == 1) }
            }
            """,
            subjectBaseName: "Slider"
        )

        let sandbox = try SandboxBuilder().make(for: subject, generatedTest: test)
        let work = Task {
            try await TestVerifier().verify(sandbox: sandbox, test: test) { _ in }
        }

        try await Task.sleep(for: .milliseconds(600))
        work.cancel()

        var wasCancelled = false
        do {
            _ = try await work.value
        } catch is CancellationError {
            wasCancelled = true
        }
        SandboxBuilder().destroy(sandbox)

        #expect(wasCancelled)
        #expect(processes(under: sandbox.packageRoot.path(percentEncoded: false)).isEmpty)
        #expect(!FileManager.default.fileExists(
            atPath: sandbox.container.path(percentEncoded: false)
        ))
        withExtendedLifetime(fixture) {}
    }

    /// Asks the system, not our own bookkeeping, whether anything is still running.
    private func processes(under path: String) -> [String] {
        let process = Process()
        process.executableURL = URL(filePath: "/bin/ps")
        process.arguments = ["-Ao", "command="]
        let pipe = Pipe()
        process.standardOutput = pipe
        guard (try? process.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
            .split(separator: "\n")
            .map(String.init)
            .filter { $0.contains(path) }
    }
}

extension Fixture {
    /// A real, buildable package with a source file and an empty test target.
    static func widgetsPackage() throws -> Fixture {
        let fixture = try Fixture()
        try fixture.write("Package.swift", """
        // swift-tools-version: 6.0
        import PackageDescription

        let package = Package(
            name: "Widgets",
            targets: [
                .target(name: "Widgets"),
                .testTarget(name: "WidgetsTests", dependencies: ["Widgets"]),
            ]
        )
        """)
        try fixture.write("Sources/Widgets/Slider.swift", """
        public struct Slider {
            public let value: Double

            public init(value: Double) {
                self.value = min(max(value, 0), 1)
            }
        }
        """)
        try fixture.makeDirectory("Tests/WidgetsTests")
        return fixture
    }
}
