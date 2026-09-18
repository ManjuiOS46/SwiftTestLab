//
//  TestFileWriter.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import Foundation

public enum WriteError: LocalizedError, Sendable, Equatable {
    case destinationExists(path: String)
    case failed(String)

    public var errorDescription: String? {
        switch self {
        case .destinationExists(let path):
            "\(path) already exists. SwiftTestLab will not overwrite a test file — if a human wrote that, it stays."
        case .failed(let reason):
            "Couldn't write the test file: \(reason)"
        }
    }
}

/// Writes a generated test into the real package. The only place this app ever
/// modifies the user's package, and it refuses to clobber anything.
public struct TestFileWriter: Sendable {
    public init() {}

    public func exists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
    }

    public func write(_ test: GeneratedTest, to url: URL) throws {
        let path = url.path(percentEncoded: false)

        // O_EXCL, not a fileExists check: the guarantee has to hold even if the
        // file appears between the check and the write.
        let descriptor = open(path, O_WRONLY | O_CREAT | O_EXCL, 0o644)
        guard descriptor >= 0 else {
            if errno == EEXIST { throw WriteError.destinationExists(path: url.lastPathComponent) }
            throw WriteError.failed(String(cString: strerror(errno)))
        }

        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        do {
            try handle.write(contentsOf: Data(test.source.utf8))
            try handle.close()
        } catch {
            try? handle.close()
            try? FileManager.default.removeItem(at: url)
            throw WriteError.failed(error.localizedDescription)
        }
    }
}
