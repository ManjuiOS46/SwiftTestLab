//
//  TestFileWriterTests.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import Foundation
import Testing
@testable import SwiftTestLabKit

@Suite struct TestFileWriterTests {
    private let test = GeneratedTest(
        source: "import Testing\n",
        suiteName: "SliderTests",
        fileName: "SliderTests.swift"
    )

    @Test func writesANewFile() throws {
        let fixture = try Fixture()
        let destination = fixture.root.appending(path: "SliderTests.swift")

        try TestFileWriter().write(test, to: destination)

        let written = try String(contentsOf: destination, encoding: .utf8)
        #expect(written == "import Testing\n")
    }

    @Test func refusesToOverwriteAFileThatIsAlreadyThere() throws {
        let fixture = try Fixture()
        try fixture.write("SliderTests.swift", "// written by a human\n")
        let destination = fixture.root.appending(path: "SliderTests.swift")

        #expect(throws: WriteError.destinationExists(path: "SliderTests.swift")) {
            try TestFileWriter().write(test, to: destination)
        }

        let untouched = try String(contentsOf: destination, encoding: .utf8)
        #expect(untouched == "// written by a human\n")
    }

    @Test func reportsWhetherADestinationIsOccupiedBeforeAnyWork() throws {
        let fixture = try Fixture()
        let writer = TestFileWriter()
        let destination = fixture.root.appending(path: "SliderTests.swift")

        #expect(!writer.exists(at: destination))
        try fixture.write("SliderTests.swift", "")
        #expect(writer.exists(at: destination))
    }
}
