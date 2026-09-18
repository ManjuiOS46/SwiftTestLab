//
//  TestFileWriterTests.swift
//  SwiftTestLab
//
//  Created by Manju on 18/09/2026.
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

@Suite struct GeneratedTestArchiveTests {
    private let test = GeneratedTest(
        source: "import Testing\n",
        suiteName: "SliderTests",
        fileName: "SliderTests.swift"
    )

    @Test func savesBesideTheSubjectFile() throws {
        let fixture = try Fixture()
        try fixture.write("Slider.swift", "struct Slider {}")
        let subject = TestSubject.standalone(
            try StandaloneFile(url: fixture.root.appending(path: "Slider.swift"))
        )

        let url = try GeneratedTestArchive().save(test, for: subject)

        #expect(url.deletingLastPathComponent().lastPathComponent == GeneratedTestArchive.folderName)
        #expect(url.lastPathComponent == "SliderTests.swift")
        #expect(try String(contentsOf: url, encoding: .utf8) == "import Testing\n")
        withExtendedLifetime(fixture) {}
    }

    @Test func neverOverwritesAnEarlierGeneration() throws {
        let fixture = try Fixture()
        try fixture.write("Slider.swift", "struct Slider {}")
        let subject = TestSubject.standalone(
            try StandaloneFile(url: fixture.root.appending(path: "Slider.swift"))
        )
        let archive = GeneratedTestArchive()

        let first = try archive.save(test, for: subject)
        let second = try archive.save(test, for: subject)
        let third = try archive.save(test, for: subject)

        #expect(first.lastPathComponent == "SliderTests.swift")
        #expect(second.lastPathComponent == "SliderTests-2.swift")
        #expect(third.lastPathComponent == "SliderTests-3.swift")
        withExtendedLifetime(fixture) {}
    }

    @Test func savesAtThePackageRootForAPackageSubject() async throws {
        let fixture = try Fixture.widgetsPackage()
        let package = try await PackageInspector().inspect(folder: fixture.root)
        let subject = TestSubject.inPackage(
            package: package,
            file: try #require(package.sourceFiles.first)
        )

        let url = try GeneratedTestArchive().save(test, for: subject)

        #expect(url.path(percentEncoded: false).hasPrefix(
            fixture.root.appending(path: GeneratedTestArchive.folderName)
                .path(percentEncoded: false)
        ))
        withExtendedLifetime(fixture) {}
    }
}
