//
//  SwiftPackage.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import Foundation

/// Which testing framework the package's existing tests are written against.
public enum TestFramework: String, Sendable, CaseIterable {
    case swiftTesting
    case xctest

    public var displayName: String {
        switch self {
        case .swiftTesting: "Swift Testing"
        case .xctest: "XCTest"
        }
    }

    public var importStatement: String {
        switch self {
        case .swiftTesting: "import Testing"
        case .xctest: "import XCTest"
        }
    }
}

/// A single Swift file under `Sources/` that a test could be generated for.
public struct SourceFile: Sendable, Identifiable, Hashable {
    public let url: URL
    /// Path relative to the package root, e.g. `Sources/Widgets/Slider.swift`.
    public let relativePath: String
    /// The module the file belongs to, which is what a test file must import.
    public let moduleName: String

    public var id: URL { url }
    public var fileName: String { url.lastPathComponent }
    /// `Slider.swift` -> `Slider`
    public var baseName: String { url.deletingPathExtension().lastPathComponent }

    public init(url: URL, relativePath: String, moduleName: String) {
        self.url = url
        self.relativePath = relativePath
        self.moduleName = moduleName
    }

    public func read() throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }
}

/// The package's test target — where a generated test would have to live.
public struct TestTargetInfo: Sendable, Hashable {
    public let name: String
    public let directory: URL
    /// Path relative to the package root, e.g. `Tests/WidgetsTests`.
    public let relativeDirectory: String
    public let framework: TestFramework
    /// How the framework was decided, shown in the UI so the choice isn't a black box.
    public let frameworkEvidence: String

    public init(
        name: String,
        directory: URL,
        relativeDirectory: String,
        framework: TestFramework,
        frameworkEvidence: String
    ) {
        self.name = name
        self.directory = directory
        self.relativeDirectory = relativeDirectory
        self.framework = framework
        self.frameworkEvidence = frameworkEvidence
    }
}

/// A validated Swift package: it has a manifest, sources, and somewhere to put a test.
public struct SwiftPackage: Sendable, Identifiable {
    public let root: URL
    public let name: String
    public let sourceFiles: [SourceFile]
    public let testTarget: TestTargetInfo

    public var id: URL { root }

    public init(root: URL, name: String, sourceFiles: [SourceFile], testTarget: TestTargetInfo) {
        self.root = root
        self.name = name
        self.sourceFiles = sourceFiles
        self.testTarget = testTarget
    }

    /// Where a test file of this name would be written, if accepted.
    public func destination(forTestFileNamed fileName: String) -> URL {
        testTarget.directory.appending(path: fileName)
    }
}
