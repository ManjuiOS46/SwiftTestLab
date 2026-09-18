//
//  DiffRenderer.swift
//  SwiftTestLab
//
//  Created by Manju on 18/09/2026.
//

import Foundation

public struct DiffLine: Sendable, Identifiable {
    public enum Kind: Sendable { case header, hunk, added }
    public let id: Int
    public let kind: Kind
    public let text: String
}

/// Renders what accepting would do to the package. Since a write is refused when
/// the destination exists, this is always an all-new file — every line is an addition.
public struct DiffRenderer: Sendable {
    public init() {}

    public func diff(test: GeneratedTest, destinationRelativePath: String) -> [DiffLine] {
        let body = test.source.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var lines: [DiffLine] = [
            DiffLine(id: 0, kind: .header, text: "--- /dev/null"),
            DiffLine(id: 1, kind: .header, text: "+++ b/\(destinationRelativePath)"),
            DiffLine(id: 2, kind: .hunk, text: "@@ -0,0 +1,\(body.count) @@"),
        ]
        for (offset, line) in body.enumerated() {
            lines.append(DiffLine(id: offset + 3, kind: .added, text: "+" + line))
        }
        return lines
    }
}
