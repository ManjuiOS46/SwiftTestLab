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
            pattern: #"throws:\s*Never\.self"#,
            reason: "asserting a non-throwing call doesn't throw is always true"
        ),
        Rule(
            pattern: #"XCTAssertNoThrow\("#,
            reason: "asserting a non-throwing call doesn't throw is always true"
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

    public static func vacuousAssertions(in source: String) -> [VacuousAssertion] {
        var found: [VacuousAssertion] = []

        for (offset, line) in source.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let text = String(line).trimmingCharacters(in: .whitespaces)
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
}

extension GeneratedTest {
    /// Assertions in this file that are true by construction.
    public var vacuousAssertions: [VacuousAssertion] {
        AssertionAudit.vacuousAssertions(in: source)
    }
}
