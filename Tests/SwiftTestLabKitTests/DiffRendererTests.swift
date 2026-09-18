//
//  DiffRendererTests.swift
//  SwiftTestLab
//
//  Created by Manju on 18/09/2026.
//

import Foundation
import Testing
@testable import SwiftTestLabKit

@Suite struct DiffRendererTests {
    @Test func rendersEveryLineAsAnAddition() {
        let test = GeneratedTest(
            source: "import Testing\n\n@Suite struct SliderTests {}\n",
            suiteName: "SliderTests",
            fileName: "SliderTests.swift"
        )

        let lines = DiffRenderer().diff(
            test: test,
            destinationRelativePath: "Tests/WidgetsTests/SliderTests.swift"
        )

        #expect(lines.first?.text == "--- /dev/null")
        #expect(lines.dropFirst().first?.text == "+++ b/Tests/WidgetsTests/SliderTests.swift")
        #expect(lines.contains { $0.text == "+import Testing" })
        #expect(lines.filter { $0.kind == .added }.allSatisfy { $0.text.hasPrefix("+") })
    }

    @Test func theHunkHeaderCountsTheLinesItShows() {
        let test = GeneratedTest(source: "a\nb\nc\n", suiteName: "X", fileName: "X.swift")
        let lines = DiffRenderer().diff(test: test, destinationRelativePath: "Tests/XTests/X.swift")

        let addedCount = lines.filter { $0.kind == .added }.count
        let hunk = lines.first { $0.kind == .hunk }?.text
        #expect(hunk == "@@ -0,0 +1,\(addedCount) @@")
    }
}
