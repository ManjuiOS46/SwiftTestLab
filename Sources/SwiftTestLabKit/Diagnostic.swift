//
//  Diagnostic.swift
//  SwiftTestLab
//
//  Created by Manju on 18/09/2026.
//

import Foundation

/// One compiler or test-runner complaint, lifted out of the build log.
///
/// SwiftPM prints the full compiler invocation when a build fails, so the lines
/// that actually say what's wrong are buried in several hundred flags. Reading
/// them out is the difference between a usable failure and a wall of text.
public struct Diagnostic: Sendable, Identifiable, Hashable {
    public enum Severity: String, Sendable {
        case error
        case warning

        public var symbolName: String {
            switch self {
            case .error: "xmark.octagon.fill"
            case .warning: "exclamationmark.triangle.fill"
            }
        }
    }

    public let file: String
    public let line: Int
    public let column: Int
    public let severity: Severity
    public let message: String

    public var id: String { "\(file):\(line):\(column):\(severity.rawValue):\(message)" }
    public var location: String { "\(file):\(line)" }
}

public enum DiagnosticParser {
    /// Duplicates removed; the generated file first, then errors, then by line.
    public static func diagnostics(in log: String, preferring fileName: String? = nil) -> [Diagnostic] {
        // Built per call: a Regex isn't Sendable, so it can't be a shared constant.
        let pattern =
            /^(?<path>[^\s:][^:]*\.swift):(?<line>\d+):(?<column>\d+): (?<severity>error|warning): (?<message>.+)$/
            .anchorsMatchLineEndings()

        // Swift Testing is macros all the way down, so a diagnostic inside `#expect`
        // is reported against the expansion buffer — "macro expansion #expect:1:61:
        // warning: ..." — with no file or line the user could act on. The compiler
        // follows it with a note giving the real location, which is what gets used.
        let macroPattern = /^macro expansion [^:]+:\d+:\d+: (?<severity>error|warning): (?<message>.+)$/
        let originPattern =
            /(?<path>[^\s:][^:]*\.swift):(?<line>\d+):(?<column>\d+): note: expanded code originates here/

        var seen = Set<String>()
        var found: [Diagnostic] = []

        func add(_ diagnostic: Diagnostic) {
            if seen.insert(diagnostic.id).inserted { found.append(diagnostic) }
        }

        let lines = log.split(separator: "\n", omittingEmptySubsequences: false)

        for (index, line) in lines.enumerated() {
            if let match = line.firstMatch(of: pattern) {
                guard let number = Int(match.line), let column = Int(match.column),
                      let severity = Diagnostic.Severity(rawValue: String(match.severity)) else { continue }
                add(
                    Diagnostic(
                        file: URL(filePath: String(match.path)).lastPathComponent,
                        line: number,
                        column: column,
                        severity: severity,
                        message: String(match.message).trimmingCharacters(in: .whitespaces)
                    )
                )
                continue
            }

            guard let macro = line.firstMatch(of: macroPattern),
                  let severity = Diagnostic.Severity(rawValue: String(macro.severity)) else { continue }

            // The note naming the real location follows within a line or two.
            let lookahead = (index + 1)...min(index + 3, lines.count - 1)
            guard lookahead.lowerBound <= lookahead.upperBound,
                  let origin = lines[lookahead].lazy
                    .compactMap({ $0.firstMatch(of: originPattern) })
                    .first,
                  let number = Int(origin.line), let column = Int(origin.column) else { continue }

            add(
                Diagnostic(
                    file: URL(filePath: String(origin.path)).lastPathComponent,
                    line: number,
                    column: column,
                    severity: severity,
                    message: String(macro.message).trimmingCharacters(in: .whitespaces)
                )
            )
        }

        return found.sorted { left, right in
            // The generated file is what the user can act on, so it comes first.
            if let fileName {
                let leftIsSubject = left.file == fileName
                let rightIsSubject = right.file == fileName
                if leftIsSubject != rightIsSubject { return leftIsSubject }
            }
            if left.severity != right.severity { return left.severity == .error }
            if left.line != right.line { return left.line < right.line }
            return left.column < right.column
        }
    }
}
