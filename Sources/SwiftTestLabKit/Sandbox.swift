//
//  Sandbox.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import Foundation

public enum SandboxError: LocalizedError, Sendable {
    case copyFailed(String)

    public var errorDescription: String? {
        switch self {
        case .copyFailed(let reason): "Couldn't prepare a scratch copy: \(reason)"
        }
    }
}

/// A throwaway package with the generated test dropped in. Verification happens
/// here and only here — the user's own files are never written to until Accept.
public struct Sandbox: Sendable {
    public let container: URL
    public let packageRoot: URL
    public let testFileURL: URL
    /// True when the package around the file was invented by us rather than cloned.
    public let isSynthesised: Bool
}

public struct SandboxBuilder: Sendable {
    /// Directories that would make the copy slow, huge, or no longer pristine.
    static let excluded: Set<String> = [".build", ".git"]

    public init() {}

    public func make(for subject: TestSubject, generatedTest: GeneratedTest) throws -> Sandbox {
        switch subject {
        case .inPackage(let package, _):
            try clone(package: package, generatedTest: generatedTest)
        case .standalone(let file):
            try synthesise(around: file, generatedTest: generatedTest)
        }
    }

    public func destroy(_ sandbox: Sandbox) {
        try? FileManager.default.removeItem(at: sandbox.container)
    }

    // MARK: - A real package, cloned

    private func clone(package: SwiftPackage, generatedTest: GeneratedTest) throws -> Sandbox {
        let fileManager = FileManager.default
        let container = Self.newContainer()
        let packageRoot = container.appending(path: package.root.lastPathComponent)

        do {
            try fileManager.createDirectory(at: packageRoot, withIntermediateDirectories: true)

            // Copy entry by entry so .build and .git can be left behind. On APFS
            // this clones rather than duplicating bytes, so it costs almost nothing.
            let entries = try fileManager.contentsOfDirectory(
                atPath: package.root.path(percentEncoded: false)
            )
            for entry in entries where !Self.excluded.contains(entry) {
                try fileManager.copyItem(
                    at: package.root.appending(path: entry),
                    to: packageRoot.appending(path: entry)
                )
            }

            let testFileURL = try write(
                generatedTest,
                into: packageRoot.appending(path: package.testTarget.relativeDirectory)
            )
            return Sandbox(
                container: container,
                packageRoot: packageRoot,
                testFileURL: testFileURL,
                isSynthesised: false
            )
        } catch {
            try? fileManager.removeItem(at: container)
            throw SandboxError.copyFailed(error.localizedDescription)
        }
    }

    // MARK: - A loose file, wrapped in a package we invent

    private func synthesise(around file: StandaloneFile, generatedTest: GeneratedTest) throws -> Sandbox {
        let fileManager = FileManager.default
        let container = Self.newContainer()
        let packageRoot = container.appending(path: StandaloneFile.moduleName)

        do {
            let sources = packageRoot.appending(path: "Sources/\(StandaloneFile.moduleName)")
            try fileManager.createDirectory(at: sources, withIntermediateDirectories: true)
            try file.read().write(
                to: sources.appending(path: file.fileName),
                atomically: true,
                encoding: .utf8
            )
            try Self.synthesisedManifest.write(
                to: packageRoot.appending(path: "Package.swift"),
                atomically: true,
                encoding: .utf8
            )

            let testFileURL = try write(
                generatedTest,
                into: packageRoot.appending(path: "Tests/\(StandaloneFile.testTargetName)")
            )
            return Sandbox(
                container: container,
                packageRoot: packageRoot,
                testFileURL: testFileURL,
                isSynthesised: true
            )
        } catch {
            try? fileManager.removeItem(at: container)
            throw SandboxError.copyFailed(error.localizedDescription)
        }
    }

    /// Swift 5 language mode on purpose: a file lifted out of somebody else's
    /// project shouldn't fail to build over strict-concurrency rules its own
    /// package may not have opted into.
    static let synthesisedManifest = """
    // swift-tools-version: 6.0
    import PackageDescription

    let package = Package(
        name: "\(StandaloneFile.moduleName)",
        platforms: [.macOS(.v14)],
        targets: [
            .target(
                name: "\(StandaloneFile.moduleName)",
                swiftSettings: [.swiftLanguageMode(.v5)]
            ),
            .testTarget(
                name: "\(StandaloneFile.testTargetName)",
                dependencies: ["\(StandaloneFile.moduleName)"],
                swiftSettings: [.swiftLanguageMode(.v5)]
            ),
        ]
    )

    """

    // MARK: - Shared

    private func write(_ generatedTest: GeneratedTest, into directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: generatedTest.fileName)
        try generatedTest.source.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func newContainer() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: "SwiftTestLab-\(UUID().uuidString)")
    }
}
