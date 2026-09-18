//
//  TestSubject.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import Foundation

public enum FileSelectionError: LocalizedError, Sendable, Equatable {
    case notASwiftFile(name: String)
    case looksLikeATestFile(name: String)
    case unreadable(name: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .notASwiftFile(let name):
            "\(name) isn't a Swift file."
        case .looksLikeATestFile(let name):
            "\(name) already looks like a test. Pick the file you want tested instead."
        case .unreadable(let name, let reason):
            "Couldn't read \(name): \(reason)"
        }
    }
}

/// One Swift file picked on its own, with no package around it.
///
/// SwiftPM can't build a loose file, so verifying one means wrapping it in a
/// throwaway package — see `SandboxBuilder`. That works when the file stands on
/// its own, and fails honestly when it depends on the rest of its project.
public struct StandaloneFile: Sendable, Identifiable, Hashable {
    public static let moduleName = "Subject"
    public static let testTargetName = "SubjectTests"

    public let url: URL

    public var id: URL { url }
    public var fileName: String { url.lastPathComponent }
    public var baseName: String { url.deletingPathExtension().lastPathComponent }
    public var directory: URL { url.deletingLastPathComponent() }

    public init(url: URL) throws {
        let name = url.lastPathComponent
        guard url.pathExtension == "swift" else {
            throw FileSelectionError.notASwiftFile(name: name)
        }
        guard !name.hasSuffix("Tests.swift") else {
            throw FileSelectionError.looksLikeATestFile(name: name)
        }
        do {
            _ = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw FileSelectionError.unreadable(name: name, reason: error.localizedDescription)
        }
        self.url = url.resolvingSymlinksInPath().standardizedFileURL
    }

    public func read() throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }
}

/// What a run is about: a file inside a package, or a file on its own.
public enum TestSubject: Sendable {
    case inPackage(package: SwiftPackage, file: SourceFile)
    case standalone(StandaloneFile)

    public var fileName: String {
        switch self {
        case .inPackage(_, let file): file.fileName
        case .standalone(let file): file.fileName
        }
    }

    public var baseName: String {
        switch self {
        case .inPackage(_, let file): file.baseName
        case .standalone(let file): file.baseName
        }
    }

    /// The module a test would have to import.
    public var moduleName: String {
        switch self {
        case .inPackage(_, let file): file.moduleName
        case .standalone: StandaloneFile.moduleName
        }
    }

    public var framework: TestFramework {
        switch self {
        case .inPackage(let package, _): package.testTarget.framework
        // A synthesised package is always current, so it gets the current framework.
        case .standalone: .swiftTesting
        }
    }

    public var locationDescription: String {
        switch self {
        case .inPackage(_, let file): file.relativePath
        case .standalone(let file): file.url.path(percentEncoded: false)
        }
    }

    public var contextDescription: String {
        switch self {
        case .inPackage(let package, _):
            "\(package.name) · \(package.testTarget.name) · \(package.testTarget.framework.displayName)"
        case .standalone:
            "Standalone file · built in a throwaway package · Swift Testing"
        }
    }

    public func source() throws -> String {
        switch self {
        case .inPackage(_, let file): try file.read()
        case .standalone(let file): try file.read()
        }
    }

    /// Where an accepted test would land, when the app can work that out itself.
    /// `nil` means the user has to choose, because there is no test target to land in.
    public func destination(forTestFileNamed fileName: String) -> URL? {
        switch self {
        case .inPackage(let package, _): package.destination(forTestFileNamed: fileName)
        case .standalone: nil
        }
    }

    public func destinationDescription(forTestFileNamed fileName: String) -> String {
        switch self {
        case .inPackage(let package, _):
            "\(package.testTarget.relativeDirectory)/\(fileName)"
        case .standalone(let file):
            "\(file.directory.lastPathComponent)/\(fileName)"
        }
    }
}
