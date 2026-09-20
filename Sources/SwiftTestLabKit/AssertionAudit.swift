//
//  AssertionAudit.swift
//  SwiftTestLab
//
//  Created by Manju on 18/09/2026.
//

import Foundation

/// An assertion that cannot fail, whatever the code under test does.
public struct VacuousAssertion: Sendable, Identifiable, Hashable {
    public let line: Int
    public let text: String
    public let reason: String

    public var id: String { "\(line):\(text)" }
}

/// Finds assertions that are true by construction.
///
/// This exists because asking the model not to write them does not work. Measured
/// against qwen3-coder:30b on a subject with no observable behaviour, the rule
/// "do not assert that a function does not throw when it is not declared to throw"
/// was followed by output doing exactly that. A test suite that passes while
/// asserting nothing is the failure mode this whole app is meant to catch, so it
/// is checked rather than requested.
public enum AssertionAudit {
    private struct Rule {
        let pattern: String
        let reason: String
    }

    private static let rules = [
        Rule(
            pattern: #"==\s*(Void\(\)|\(\))"#,
            reason: "comparing Void to Void is always true"
        ),
        Rule(
            pattern: #"#expect\([^)\n]*\bis\s+[A-Z][A-Za-z0-9_]*\s*\)"#,
            reason: "a value is always the type it was constructed as"
        ),
        Rule(
            pattern: #"#expect\(\s*(true|Bool\(true\))\s*\)"#,
            reason: "always true"
        ),
        Rule(
            pattern: #"XCTAssertTrue\(\s*true\s*\)"#,
            reason: "always true"
        ),
        Rule(
            pattern: #"(#expect|XCTAssertNotNil)\([A-Z][A-Za-z0-9_]*\([^)\n]*\)\s*(!=\s*nil)?\)"#,
            reason: "a freshly constructed value is never nil"
        ),
        Rule(
            pattern: #"#expect\([a-zA-Z_][A-Za-z0-9_.]*\s*==\s*\1\s*\)"#,
            reason: "comparing a value to itself is always true"
        ),
    ]

    /// Assertions that are unfailable on the face of the source.
    ///
    /// `#expect(throws: Never.self)` and `XCTAssertNoThrow` deliberately aren't
    /// here. Both are correct and useful against a function that really does
    /// throw — the Swift Testing documentation teaches the first as the way to
    /// assert a success path. They are vacuous only when the call cannot throw,
    /// which the source alone does not say. Use `confirmedBy:` for those.
    public static func vacuousAssertions(in source: String) -> [VacuousAssertion] {
        var found: [VacuousAssertion] = []

        for (offset, line) in lines(of: source).enumerated() {
            let text = line.trimmingCharacters(in: .whitespaces)
            guard text.contains("#expect") || text.contains("XCTAssert") else { continue }

            for rule in rules {
                guard let regex = try? Regex(rule.pattern), text.contains(regex) else { continue }
                found.append(
                    VacuousAssertion(line: offset + 1, text: text, reason: rule.reason)
                )
                break
            }
        }

        return found
    }

    /// The above, plus no-throw assertions the compiler has shown to be pointless.
    ///
    /// When a test says a call doesn't throw and the call cannot throw, the
    /// compiler says so itself: `no calls to throwing functions occur within 'try'
    /// expression`. That warning is proof, where a pattern in the source is only a
    /// guess, so it is what the no-throw case is judged on.
    public static func vacuousAssertions(
        in source: String,
        confirmedBy diagnostics: [Diagnostic],
        inFileNamed fileName: String? = nil
    ) -> [VacuousAssertion] {
        var found = vacuousAssertions(in: source)
        let sourceLines = lines(of: source)

        for diagnostic in diagnostics where diagnostic.severity == .warning {
            guard diagnostic.message.contains("no calls to throwing functions occur") else { continue }
            if let fileName, diagnostic.file != fileName { continue }

            // The warning points at the `try`; the assertion wrapping it may be on
            // that line or just above it.
            let index = diagnostic.line - 1
            guard sourceLines.indices.contains(index) else { continue }

            let window = stride(from: index, through: max(0, index - 2), by: -1)
            guard let assertionIndex = window.first(where: { candidate in
                let text = sourceLines[candidate]
                return text.contains("Never.self") || text.contains("XCTAssertNoThrow")
            }) else { continue }

            let assertion = VacuousAssertion(
                line: assertionIndex + 1,
                text: sourceLines[assertionIndex].trimmingCharacters(in: .whitespaces),
                reason: "the compiler reports this call cannot throw, so asserting it doesn't throw cannot fail"
            )
            if !found.contains(where: { $0.line == assertion.line }) {
                found.append(assertion)
            }
        }

        return found.sorted { $0.line < $1.line }
    }

    private static func lines(of source: String) -> [String] {
        source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }
}

extension GeneratedTest {
    /// Assertions in this file that are true by construction.
    public var vacuousAssertions: [VacuousAssertion] {
        AssertionAudit.vacuousAssertions(in: source)
    }
}
