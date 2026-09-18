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
    /// Used only when the file's own module can't be worked out.
    public static let fallbackModuleName = "Subject"

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

    /// The module this file really belongs to, so the generated test imports a
    /// name that exists in the user's project rather than one we invented.
    ///
    /// `.../Sources/PixiiCloneApp/Models.swift` is module `PixiiCloneApp`, by the
    /// convention SwiftPM itself uses.
    public var moduleName: String {
        // A Swift package: Sources/<Module>/File.swift, SwiftPM's own convention.
        let components = url.pathComponents
        if let sources = components.lastIndex(of: "Sources"),
           components.index(after: sources) < components.count - 1,
           let identifier = Self.asSwiftIdentifier(components[components.index(after: sources)]) {
            return identifier
        }

        // An Xcode project: the module is the target, which for the common
        // single-target app is the project's own name.
        if let project = Self.enclosingXcodeProjectName(of: directory),
           let identifier = Self.asSwiftIdentifier(project) {
            return identifier
        }

        // Otherwise the folder the file sits in is the best guess available.
        if let identifier = Self.asSwiftIdentifier(directory.lastPathComponent) {
            return identifier
        }

        return Self.fallbackModuleName
    }

    /// Walks up looking for an `.xcodeproj`, returning its name without the suffix.
    static func enclosingXcodeProjectName(of directory: URL) -> String? {
        var current = directory.standardizedFileURL
        for _ in 0..<8 {
            let entries = (try? FileManager.default.contentsOfDirectory(
                atPath: current.path(percentEncoded: false)
            )) ?? []
            if let project = entries.first(where: { $0.hasSuffix(".xcodeproj") }) {
                return String(project.dropLast(".xcodeproj".count))
            }
            let parent = current.deletingLastPathComponent().standardizedFileURL
            guard parent.path(percentEncoded: false) != current.path(percentEncoded: false) else { break }
            current = parent
        }
        return nil
    }

    public var testTargetName: String { "\(moduleName)Tests" }

    /// A module name has to be a usable Swift identifier.
    static func asSwiftIdentifier(_ name: String) -> String? {
        let allowed = name.unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0) || $0 == "_"
        }
        let cleaned = String(String.UnicodeScalarView(allowed))
        guard let first = cleaned.first, !first.isNumber else { return nil }
        return cleaned.isEmpty ? nil : cleaned
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
        case .standalone(let file): file.moduleName
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
