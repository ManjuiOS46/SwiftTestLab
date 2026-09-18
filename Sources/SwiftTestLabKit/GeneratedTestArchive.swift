//
//  GeneratedTestArchive.swift
//  SwiftTestLab
//
//  Created by Manju on 18/09/2026.
//

import Foundation

/// Whatever the model produced is written to disk, always.
///
/// Verification still happens in a scratch copy and Accept still governs the real
/// test target — but nothing the user watched arrive should ever be lost, whether
/// it parsed, compiled, passed, failed, or died half-written.
public struct GeneratedTestArchive: Sendable {
    public static let folderName = "SwiftTestLabTests"

    public init() {}

    public func directory(for subject: TestSubject) -> URL {
        subject.archiveRoot.appending(path: Self.folderName)
    }

    /// A parsed, compilable test file.
    @discardableResult
    public func save(_ test: GeneratedTest, for subject: TestSubject) throws -> URL {
        try write(test.source, named: test.fileName, for: subject)
    }

    /// A reply that couldn't be parsed into a test file, or output from a run that
    /// stopped partway. Kept as text so it's obvious it isn't ready to compile.
    @discardableResult
    public func saveUnusable(
        _ text: String,
        for subject: TestSubject,
        reason: UnusableReason
    ) throws -> URL {
        try write(text, named: "\(subject.baseName)Tests-\(reason.rawValue).txt", for: subject)
    }

    public enum UnusableReason: String, Sendable {
        /// The reply arrived but wasn't a test file.
        case unparsed
        /// Generation stopped before the reply was complete.
        case partial
    }

    /// Never overwrites: a name already taken gets a numbered suffix.
    private func write(_ contents: String, named fileName: String, for subject: TestSubject) throws -> URL {
        let directory = directory(for: subject)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let url = URL(filePath: fileName)
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension

        var candidate = directory.appending(path: fileName)
        var suffix = 2
        while FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) {
            candidate = directory.appending(path: "\(base)-\(suffix).\(ext)")
            suffix += 1
        }

        try contents.write(to: candidate, atomically: true, encoding: .utf8)
        return candidate
    }
}

extension TestSubject {
    /// Where the archive folder goes.
    ///
    /// Never inside a `Sources/` directory: SwiftPM compiles everything under a
    /// target's path, so a file saved there becomes part of the user's build and
    /// breaks it. For a loose file that happens to live inside a package, the
    /// package root is both safe and where you'd look for it.
    var archiveRoot: URL {
        switch self {
        case .inPackage(let package, _):
            package.root
        case .standalone(let file):
            TestSubject.enclosingPackageRoot(of: file.directory)
                ?? TestSubject.aboveAnySourcesDirectory(file.directory)
        }
    }

    static func enclosingPackageRoot(of directory: URL) -> URL? {
        var current = directory.standardizedFileURL
        for _ in 0..<16 {
            let manifest = current.appending(path: "Package.swift")
            if FileManager.default.fileExists(atPath: manifest.path(percentEncoded: false)) {
                return current
            }
            let parent = current.deletingLastPathComponent().standardizedFileURL
            guard parent.path(percentEncoded: false) != current.path(percentEncoded: false) else { break }
            current = parent
        }
        return nil
    }

    /// Last resort for a file under some `Sources/` with no manifest above it:
    /// climb out of that directory rather than write into a compiled tree.
    static func aboveAnySourcesDirectory(_ directory: URL) -> URL {
        var current = directory.standardizedFileURL
        while current.pathComponents.contains("Sources") || current.pathComponents.contains("Tests") {
            let parent = current.deletingLastPathComponent().standardizedFileURL
            guard parent.path(percentEncoded: false) != current.path(percentEncoded: false) else { break }
            current = parent
        }
        return current
    }
}
