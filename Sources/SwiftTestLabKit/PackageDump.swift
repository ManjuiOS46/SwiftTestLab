//
//  PackageDump.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import Foundation

/// SwiftPM's own description of a package.
///
/// `Package.swift` is a Swift program, not a data file: targets can be built in a
/// loop, names can come from constants, paths can be anything. Reading it with a
/// regex works for the common shape and quietly mis-reads the rest — so ask the
/// tool that actually evaluates it.
struct PackageDump: Decodable {
    struct Target: Decodable {
        let name: String
        let type: String
        let path: String?
        /// Every name mentioned in the target's dependencies, however it was written
        /// (`byName`, `.target`, `.product`). Enough to answer "can this target see
        /// that module", which is all we need it for.
        let dependencyNames: [String]

        var isTest: Bool { type == "test" }
        var isSource: Bool { type == "regular" || type == "executable" || type == "macro" }

        private enum CodingKeys: String, CodingKey { case name, type, path, dependencies }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            type = try container.decode(String.self, forKey: .type)
            path = try container.decodeIfPresent(String.self, forKey: .path)
            let dependencies = try container.decodeIfPresent(JSONValue.self, forKey: .dependencies)
            dependencyNames = dependencies?.strings ?? []
        }
    }

    /// Just enough JSON to pull the strings out of a shape that varies.
    private enum JSONValue: Decodable {
        case string(String)
        case array([JSONValue])
        case object([String: JSONValue])
        case other

        init(from decoder: Decoder) throws {
            if let value = try? decoder.singleValueContainer().decode(String.self) {
                self = .string(value)
            } else if let value = try? decoder.singleValueContainer().decode([JSONValue].self) {
                self = .array(value)
            } else if let value = try? decoder.singleValueContainer().decode([String: JSONValue].self) {
                self = .object(value)
            } else {
                self = .other
            }
        }

        var strings: [String] {
            switch self {
            case .string(let value): [value]
            case .array(let values): values.flatMap(\.strings)
            case .object(let values): values.values.flatMap(\.strings)
            case .other: []
            }
        }
    }

    let name: String
    let targets: [Target]

    var testTargets: [Target] { targets.filter(\.isTest) }
    var sourceTargets: [Target] { targets.filter(\.isSource) }
}

enum PackageDumpLoader {
    /// Returns nil when SwiftPM couldn't be run at all, so the caller can fall back
    /// to reading the manifest as text. Throws when SwiftPM ran and rejected the
    /// manifest — that's a real answer and worth reporting as itself.
    static func dump(at root: URL) async throws -> PackageDump? {
        let swift = URL(filePath: "/usr/bin/swift")
        guard FileManager.default.isExecutableFile(atPath: swift.path(percentEncoded: false)) else {
            return nil
        }

        let process = Process()
        process.executableURL = swift
        process.arguments = ["package", "dump-package"]
        process.currentDirectoryURL = root
        process.standardInput = FileHandle.nullDevice

        // Kept apart: SwiftPM writes warnings to stderr, and mixing them into
        // stdout would corrupt the JSON.
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors

        do {
            try process.run()
        } catch {
            return nil
        }

        let outputData = try await read(output)
        let errorData = try await read(errors)
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let reason = String(decoding: errorData, as: UTF8.self)
                .split(separator: "\n")
                .first { $0.contains("error:") }
                .map { String($0) }
                ?? "swift package dump-package failed"
            throw PackageInspectionError.manifestRejected(reason: reason)
        }

        return try? JSONDecoder().decode(PackageDump.self, from: outputData)
    }

    private static func read(_ pipe: Pipe) async throws -> Data {
        try await Task.detached { try pipe.fileHandleForReading.readToEnd() ?? Data() }.value
    }
}
