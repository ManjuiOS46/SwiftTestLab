//
//  PackageInspector.swift
//  SwiftTestLab
//
//  Created by Manju on 18/09/2026.
//

import Foundation

public enum PackageInspectionError: LocalizedError, Sendable, Equatable {
    case notADirectory(URL)
    case notASwiftPackage(URL)
    case xcodeProjectUnsupported(URL)
    case noSourcesDirectory(URL)
    case noSourceFiles(URL)
    case noTestTarget(packageName: String, nestedPackages: [String])
    case manifestRejected(reason: String)
    case testDirectoryMissing(targetName: String)
    case unreadableManifest(String)

    public var errorDescription: String? {
        switch self {
        case .notADirectory(let url):
            "\(url.lastPathComponent) is not a folder."
        case .notASwiftPackage(let url):
            "\(url.lastPathComponent) has no Package.swift at its root, so it isn't a Swift Package."
        case .xcodeProjectUnsupported(let url):
            "\(url.lastPathComponent) is an Xcode project, not a Swift Package. SwiftTestLab only works with packages that have a Package.swift at the root."
        case .noSourcesDirectory(let url):
            "\(url.lastPathComponent) has a Package.swift but no Sources/ directory."
        case .noSourceFiles(let url):
            "No Swift files found under \(url.lastPathComponent)/Sources that aren't already tests."
        case .noTestTarget(let packageName, let nested) where !nested.isEmpty:
            "\(packageName) has no test target of its own, but it contains \(nested.count) package\(nested.count == 1 ? "" : "s"): \(nested.joined(separator: ", ")). Open one of those instead."
        case .noTestTarget(let packageName, _):
            "\(packageName) has no test target. SwiftTestLab won't create one for you — add a .testTarget to Package.swift and a Tests/ directory first."
        case .manifestRejected(let reason):
            "SwiftPM couldn't read this Package.swift: \(reason)"
        case .testDirectoryMissing(let targetName):
            "The manifest declares a test target named \(targetName), but its directory under Tests/ doesn't exist."
        case .unreadableManifest(let reason):
            "Couldn't read Package.swift: \(reason)"
        }
    }
}

/// Validates a folder as a Swift Package and works out what can be tested and how.
public struct PackageInspector: Sendable {
    public init() {}

    public func inspect(folder: URL) async throws -> SwiftPackage {
        let fileManager = FileManager.default
        let root = folder.resolvingSymlinksInPath().standardizedFileURL

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: root.path(percentEncoded: false), isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw PackageInspectionError.notADirectory(folder)
        }

        let manifestURL = root.appending(path: "Package.swift")
        guard fileManager.fileExists(atPath: manifestURL.path(percentEncoded: false)) else {
            if Self.containsXcodeProject(root, fileManager: fileManager) {
                throw PackageInspectionError.xcodeProjectUnsupported(folder)
            }
            throw PackageInspectionError.notASwiftPackage(folder)
        }

        let manifest: String
        do {
            manifest = try String(contentsOf: manifestURL, encoding: .utf8)
        } catch {
            throw PackageInspectionError.unreadableManifest(error.localizedDescription)
        }

        // SwiftPM's own reading of the manifest, when it can be had. The textual
        // parse below is a fallback for when the toolchain isn't reachable.
        let dump = try await PackageDumpLoader.dump(at: root)

        let packageName = dump?.name ?? Self.packageName(in: manifest) ?? root.lastPathComponent

        let sourcesDirectory = root.appending(path: "Sources")
        guard dump != nil || fileManager.fileExists(atPath: sourcesDirectory.path(percentEncoded: false)) else {
            throw PackageInspectionError.noSourcesDirectory(folder)
        }

        let sourceFiles = Self.sourceFiles(
            for: dump,
            packageRoot: root,
            packageName: packageName
        )
        guard !sourceFiles.isEmpty else {
            throw PackageInspectionError.noSourceFiles(folder)
        }

        let testTargetName: String
        if let dump {
            guard let target = dump.testTargets.first else {
                throw PackageInspectionError.noTestTarget(
                    packageName: packageName,
                    nestedPackages: Self.nestedPackages(in: root, fileManager: fileManager)
                )
            }
            testTargetName = target.name
        } else if let name = Self.firstTestTargetName(in: manifest) {
            testTargetName = name
        } else {
            throw PackageInspectionError.noTestTarget(
                packageName: packageName,
                nestedPackages: Self.nestedPackages(in: root, fileManager: fileManager)
            )
        }

        let declaredPath = dump?.testTargets.first?.path
        guard let testDirectory = Self.testDirectory(
            named: testTargetName,
            declaredPath: declaredPath,
            packageRoot: root,
            fileManager: fileManager
        ) else {
            throw PackageInspectionError.testDirectoryMissing(targetName: testTargetName)
        }

        let (framework, evidence) = Self.detectFramework(
            inTestDirectory: testDirectory,
            manifest: manifest
        )

        let testTarget = TestTargetInfo(
            name: testTargetName,
            directory: testDirectory,
            relativeDirectory: Self.relativePath(of: testDirectory, from: root),
            framework: framework,
            frameworkEvidence: evidence,
            dependencyNames: dump?.testTargets.first?.dependencyNames ?? []
        )

        return SwiftPackage(
            root: root,
            name: packageName,
            sourceFiles: sourceFiles,
            testTarget: testTarget
        )
    }

    // MARK: - Manifest parsing
    //
    // Deliberately textual. Evaluating the manifest properly means running SwiftPM,
    // which is slower than the whole rest of this app and buys very little here.

    static func packageName(in manifest: String) -> String? {
        guard let packageCall = manifest.range(of: "Package(") else { return nil }
        let tail = manifest[packageCall.upperBound...]
        return tail.firstMatch(of: /name:\s*"([^"]+)"/).map { String($0.1) }
    }

    static func firstTestTargetName(in manifest: String) -> String? {
        manifest.firstMatch(of: /\.testTarget\s*\(\s*name:\s*"([^"]+)"/).map { String($0.1) }
    }

    static func toolsVersionMajor(in manifest: String) -> Int? {
        manifest.firstMatch(of: /swift-tools-version:\s*([0-9]+)/).flatMap { Int($0.1) }
    }

    // MARK: - Discovery

    private static func containsXcodeProject(_ root: URL, fileManager: FileManager) -> Bool {
        let entries = (try? fileManager.contentsOfDirectory(atPath: root.path(percentEncoded: false))) ?? []
        return entries.contains { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }
    }

    /// Source files from the targets SwiftPM reports, falling back to `Sources/`.
    static func sourceFiles(for dump: PackageDump?, packageRoot: URL, packageName: String) -> [SourceFile] {
        guard let dump else {
            return sourceFiles(
                under: packageRoot.appending(path: "Sources"),
                packageRoot: packageRoot,
                packageName: packageName
            )
        }

        var files: [SourceFile] = []
        for target in dump.sourceTargets {
            let directory = packageRoot.appending(path: target.path ?? "Sources/\(target.name)")
            files += sourceFiles(
                under: directory,
                packageRoot: packageRoot,
                packageName: packageName,
                moduleName: target.name
            )
        }
        return files.sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
    }

    /// Every `.swift` file under a directory that isn't itself a test.
    static func sourceFiles(
        under sourcesDirectory: URL,
        packageRoot: URL,
        packageName: String,
        moduleName: String? = nil
    ) -> [SourceFile] {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: sourcesDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var files: [SourceFile] = []
        for case let url as URL in enumerator {
            guard url.pathExtension == "swift" else { continue }

            let components = url.pathComponents
            // .build is hidden so the enumerator skips it, but a vendored copy may not be.
            if components.contains(".build") || components.contains("Tests") { continue }
            let fileName = url.lastPathComponent
            if fileName.hasSuffix("Tests.swift") { continue }

            let relativePath = relativePath(of: url, from: packageRoot)
            files.append(
                SourceFile(
                    url: url.resolvingSymlinksInPath().standardizedFileURL,
                    relativePath: relativePath,
                    moduleName: moduleName
                        ?? self.moduleName(forRelativePath: relativePath, packageName: packageName)
                )
            )
        }
        return files.sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
    }

    /// `Sources/Widgets/Slider.swift` -> `Widgets`. A file sitting directly in
    /// `Sources/` belongs to the package's single module.
    static func moduleName(forRelativePath relativePath: String, packageName: String) -> String {
        let components = relativePath.split(separator: "/")
        guard components.count > 2, components.first == "Sources" else { return packageName }
        return String(components[1])
    }

    /// Every directory directly inside `root` that is itself a package.
    static func nestedPackages(in root: URL, fileManager: FileManager) -> [String] {
        let entries = (try? fileManager.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        return entries
            .filter {
                fileManager.fileExists(
                    atPath: $0.appending(path: "Package.swift").path(percentEncoded: false)
                )
            }
            .map(\.lastPathComponent)
            .sorted()
    }

    private static func testDirectory(
        named targetName: String,
        declaredPath: String?,
        packageRoot: URL,
        fileManager: FileManager
    ) -> URL? {
        // A target may declare its own path; that beats any convention.
        if let declaredPath {
            let declared = packageRoot.appending(path: declaredPath)
            if fileManager.fileExists(atPath: declared.path(percentEncoded: false)) { return declared }
        }
        let testsRoot = packageRoot.appending(path: "Tests")
        let byName = testsRoot.appending(path: targetName)
        if fileManager.fileExists(atPath: byName.path(percentEncoded: false)) { return byName }

        // A test target may use a custom `path:`. If Tests/ has exactly one
        // subdirectory, that's unambiguous enough to use.
        let entries = (try? fileManager.contentsOfDirectory(
            at: testsRoot,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let directories = entries.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
        return directories.count == 1 ? directories[0] : nil
    }

    /// Prefers what the package's own tests already use; falls back to the tools version.
    static func detectFramework(inTestDirectory directory: URL, manifest: String) -> (TestFramework, String) {
        let fileManager = FileManager.default
        var swiftTestingFiles = 0
        var xctestFiles = 0

        if let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) {
            for case let url as URL in enumerator where url.pathExtension == "swift" {
                guard let contents = try? String(contentsOf: url, encoding: .utf8) else { continue }
                if contents.contains(/^\s*import\s+Testing\b/.anchorsMatchLineEndings()) { swiftTestingFiles += 1 }
                if contents.contains(/^\s*import\s+XCTest\b/.anchorsMatchLineEndings()) { xctestFiles += 1 }
            }
        }

        if swiftTestingFiles > 0 || xctestFiles > 0 {
            let framework: TestFramework = swiftTestingFiles >= xctestFiles ? .swiftTesting : .xctest
            let evidence = "existing tests import \(framework == .swiftTesting ? "Testing" : "XCTest")"
                + (swiftTestingFiles > 0 && xctestFiles > 0
                   ? " (\(swiftTestingFiles) Swift Testing, \(xctestFiles) XCTest)"
                   : "")
            return (framework, evidence)
        }

        let major = toolsVersionMajor(in: manifest) ?? 5
        if major >= 6 {
            return (.swiftTesting, "no existing tests; swift-tools-version \(major) supports Swift Testing")
        }
        return (.xctest, "no existing tests; swift-tools-version \(major) predates Swift Testing")
    }

    static func relativePath(of url: URL, from root: URL) -> String {
        let rootPath = root.path(percentEncoded: false)
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path(percentEncoded: false)
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard path.hasPrefix(prefix) else { return url.lastPathComponent }
        // A directory URL reports a trailing slash; nothing downstream wants one.
        var relative = String(path.dropFirst(prefix.count))
        while relative.hasSuffix("/") { relative.removeLast() }
        return relative
    }
}
