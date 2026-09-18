//
//  TestVerifier.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import Foundation

public enum VerifierError: LocalizedError, Sendable {
    case swiftNotFound

    public var errorDescription: String? {
        switch self {
        case .swiftNotFound:
            "No Swift toolchain found at /usr/bin/swift. Install the Xcode Command Line Tools with: xcode-select --install"
        }
    }
}

public enum VerificationStage: Sendable, Equatable {
    case building
    case running
}

public enum VerificationOutcome: Sendable, Equatable {
    case passed
    case compileFailed
    case testsFailed
    case noTestsRan
    case timedOut(stage: String)
}

public struct VerificationReport: Sendable {
    public let outcome: VerificationOutcome
    public let buildLog: String
    public let testLog: String
    /// The file the test was written as, so its own diagnostics can be shown first.
    public var testFileName: String?

    public init(
        outcome: VerificationOutcome,
        buildLog: String,
        testLog: String,
        testFileName: String? = nil
    ) {
        self.outcome = outcome
        self.buildLog = buildLog
        self.testLog = testLog
        self.testFileName = testFileName
    }

    /// What actually went wrong, without the compiler invocation around it.
    public var diagnostics: [Diagnostic] {
        DiagnosticParser.diagnostics(in: buildLog + "\n" + testLog, preferring: testFileName)
    }

    public var errors: [Diagnostic] { diagnostics.filter { $0.severity == .error } }

    public var compiled: Bool {
        switch outcome {
        case .passed, .testsFailed, .noTestsRan: true
        case .compileFailed: false
        case .timedOut(let stage): stage != "build"
        }
    }

    public var passed: Bool { outcome == .passed }

    public var headline: String {
        switch outcome {
        case .passed: "Compiled and passed"
        case .compileFailed: "Did not compile"
        case .testsFailed: "Compiled, but tests failed"
        case .noTestsRan: "Compiled, but no tests ran"
        case .timedOut(let stage): "Timed out during \(stage)"
        }
    }

    public var detail: String {
        switch outcome {
        case .passed:
            "swift build --build-tests succeeded and every test in the suite passed."
        case .compileFailed:
            "The generated test doesn't compile against this package. The compiler output is below."
        case .testsFailed:
            "The test file builds, but at least one assertion failed. That may be the test being wrong, or the code being wrong — the output below is the whole story."
        case .noTestsRan:
            "The file built, but swift test matched no tests with that filter."
        case .timedOut(let stage):
            "The \(stage) step ran past its timeout and was stopped."
        }
    }
}

/// Builds and runs the generated test inside the sandbox copy.
///
/// There is deliberately no retry here: this type reports what happened once.
public struct TestVerifier: Sendable {
    private let runner = ProcessRunner()

    public init() {}

    public func verify(
        sandbox: Sandbox,
        test: GeneratedTest,
        buildTimeout: Duration = .seconds(900),
        testTimeout: Duration = .seconds(300),
        onStage: @escaping @Sendable (VerificationStage) -> Void = { _ in },
        onOutput: @escaping @Sendable (String) -> Void
    ) async throws -> VerificationReport {
        let swift = try Self.swiftExecutable()

        onStage(.building)
        onOutput("$ swift build --build-tests\n")
        let build = try await runner.run(
            executable: swift,
            arguments: ["build", "--build-tests"],
            workingDirectory: sandbox.packageRoot,
            timeout: buildTimeout,
            onOutput: onOutput
        )
        if build.timedOut {
            return VerificationReport(outcome: .timedOut(stage: "build"), buildLog: build.output, testLog: "", testFileName: test.fileName)
        }
        guard build.succeeded else {
            return VerificationReport(outcome: .compileFailed, buildLog: build.output, testLog: "", testFileName: test.fileName)
        }

        onStage(.running)
        onOutput("\n$ swift test --filter \(test.suiteName)\n")
        let run = try await runner.run(
            executable: swift,
            arguments: ["test", "--filter", test.suiteName],
            workingDirectory: sandbox.packageRoot,
            timeout: testTimeout,
            onOutput: onOutput
        )
        if run.timedOut {
            return VerificationReport(outcome: .timedOut(stage: "test run"), buildLog: build.output, testLog: run.output, testFileName: test.fileName)
        }
        if run.succeeded {
            return VerificationReport(outcome: .passed, buildLog: build.output, testLog: run.output, testFileName: test.fileName)
        }
        if Self.matchedNothing(run.output) {
            return VerificationReport(outcome: .noTestsRan, buildLog: build.output, testLog: run.output, testFileName: test.fileName)
        }
        return VerificationReport(outcome: .testsFailed, buildLog: build.output, testLog: run.output, testFileName: test.fileName)
    }

    static func matchedNothing(_ log: String) -> Bool {
        log.contains("No matching test cases were run")
            || log.contains("Executed 0 tests")
            || log.contains("no tests found")
    }

    /// `/usr/bin/swift` forwards to whichever toolchain is selected, which is what
    /// the user would get in their own terminal.
    static func swiftExecutable() throws -> URL {
        let shim = URL(filePath: "/usr/bin/swift")
        guard FileManager.default.isExecutableFile(atPath: shim.path(percentEncoded: false)) else {
            throw VerifierError.swiftNotFound
        }
        return shim
    }
}
