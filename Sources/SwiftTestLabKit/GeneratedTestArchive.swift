//
//  GeneratedTestArchive.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import Foundation

/// Every generated test is written to disk the moment it arrives, before any
/// build happens, into a folder of its own beside the subject.
///
/// Verification still happens in a scratch copy and Accept still governs the real
/// test target — but a file you watched being written should never be something
/// you have to take on trust.
public struct GeneratedTestArchive: Sendable {
    public static let folderName = "SwiftTestLabTests"

    public init() {}

    public func directory(for subject: TestSubject) -> URL {
        subject.archiveRoot.appending(path: Self.folderName)
    }

    /// Writes the file, never overwriting: a name already taken gets a suffix.
    @discardableResult
    public func save(_ test: GeneratedTest, for subject: TestSubject) throws -> URL {
        let directory = directory(for: subject)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let base = test.fileName.replacingOccurrences(of: ".swift", with: "")
        var candidate = directory.appending(path: test.fileName)
        var suffix = 2
        while FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) {
            candidate = directory.appending(path: "\(base)-\(suffix).swift")
            suffix += 1
        }

        try test.source.write(to: candidate, atomically: true, encoding: .utf8)
        return candidate
    }
}

extension TestSubject {
    /// The folder the archive sits beside: the package root, or the file's own folder.
    var archiveRoot: URL {
        switch self {
        case .inPackage(let package, _): package.root
        case .standalone(let file): file.directory
        }
    }
}
