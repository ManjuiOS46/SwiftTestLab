//
//  TestCodeExtractor.swift
//  SwiftTestLab
//
//  Created by Manju on 18/09/2026.
//

import Foundation

public enum ExtractionError: LocalizedError, Sendable, Equatable {
    case notATestFile
    case noTypeDeclaration

    public var errorDescription: String? {
        switch self {
        case .notATestFile:
            "The model's reply doesn't look like a test file — no imports or assertions in it."
        case .noTypeDeclaration:
            "Couldn't find a suite or test class in the model's reply, so there's nothing to run."
        }
    }
}

/// One generated test file, ready to be compiled.
public struct GeneratedTest: Sendable {
    /// The Swift source, fences and any stray prose removed.
    public let source: String
    /// The suite or class name, used as the `swift test --filter` argument.
    public let suiteName: String
    /// The file name it would be written as.
    public let fileName: String

    public init(source: String, suiteName: String, fileName: String) {
        self.source = source
        self.suiteName = suiteName
        self.fileName = fileName
    }
}

/// Turns a model reply into something that can be written to disk and filtered on.
public struct TestCodeExtractor: Sendable {
    public init() {}

    public func extract(from reply: String, subjectBaseName: String) throws -> GeneratedTest {
        let source = Self.stripFences(from: Self.stripReasoning(from: reply))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard source.contains("import "),
              source.contains("@Test") || source.contains("func test")
                || source.contains("#expect") || source.contains("XCTAssert") else {
            throw ExtractionError.notATestFile
        }
        guard let suiteName = Self.suiteName(in: source) else {
            throw ExtractionError.noTypeDeclaration
        }

        let fileName = suiteName.hasSuffix("Tests")
            ? "\(suiteName).swift"
            : "\(subjectBaseName)Tests.swift"

        return GeneratedTest(source: source + "\n", suiteName: suiteName, fileName: fileName)
    }

    /// Open reasoning models emit their scratchpad inline. It is not part of the file.
    static func stripReasoning(from reply: String) -> String {
        reply.replacing(/(?s)<(think|thinking|reasoning)>.*?<\/\1>/, with: "")
    }

    /// The instructions say no fences, but a model that adds them anyway shouldn't
    /// produce a file that fails to compile for that reason alone.
    static func stripFences(from reply: String) -> String {
        guard let opening = reply.firstRange(of: /```[a-zA-Z]*\n/) else { return reply }
        let afterOpening = reply[opening.upperBound...]
        guard let closing = afterOpening.firstRange(of: "```") else { return String(afterOpening) }
        return String(afterOpening[..<closing.lowerBound])
    }

    /// Prefers a declared type whose name ends in `Tests`; otherwise takes the first
    /// type declared, which is what `--filter` will have to match.
    static func suiteName(in source: String) -> String? {
        let declaration = /(?:struct|final\s+class|class|actor|enum)\s+([A-Za-z_][A-Za-z0-9_]*)/
        let names = source.matches(of: declaration).map { String($0.1) }
        return names.first { $0.hasSuffix("Tests") } ?? names.first
    }
}
