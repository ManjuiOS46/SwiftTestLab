//
//  ArchiveLocationTests.swift
//  SwiftTestLab
//
//  Created by Manju on 18/09/2026.
//

import Foundation
import Testing
@testable import SwiftTestLabKit

/// Where a generated file lands matters more than it sounds: anything written
/// under `Sources/` becomes part of the user's build and breaks it.
@Suite struct ArchiveLocationTests {
    private let test = GeneratedTest(
        source: "import Testing\n",
        suiteName: "ThingTests",
        fileName: "ThingTests.swift"
    )

    @Test func aLooseFileInsideAPackageArchivesAtThePackageRoot() throws {
        let fixture = try Fixture()
        try fixture.write("Package.swift", "// swift-tools-version: 6.0")
        try fixture.write("Sources/App/Thing.swift", "struct Thing {}")
        let subject = TestSubject.standalone(
            try StandaloneFile(url: fixture.root.appending(path: "Sources/App/Thing.swift"))
        )

        let url = try GeneratedTestArchive().save(test, for: subject)
        let path = url.path(percentEncoded: false)

        #expect(!path.contains("/Sources/"))
        #expect(path.hasPrefix(
            fixture.root.appending(path: GeneratedTestArchive.folderName)
                .path(percentEncoded: false)
        ))
        withExtendedLifetime(fixture) {}
    }

    @Test func aLooseFileUnderSourcesWithNoManifestStillClimbsOut() throws {
        let fixture = try Fixture()
        try fixture.write("Sources/App/Thing.swift", "struct Thing {}")
        let subject = TestSubject.standalone(
            try StandaloneFile(url: fixture.root.appending(path: "Sources/App/Thing.swift"))
        )

        let url = try GeneratedTestArchive().save(test, for: subject)
        #expect(!url.path(percentEncoded: false).contains("/Sources/"))
        withExtendedLifetime(fixture) {}
    }

    @Test func anOrdinaryLooseFileArchivesBesideItself() throws {
        let fixture = try Fixture()
        try fixture.write("Thing.swift", "struct Thing {}")
        let subject = TestSubject.standalone(
            try StandaloneFile(url: fixture.root.appending(path: "Thing.swift"))
        )

        let url = try GeneratedTestArchive().save(test, for: subject)
        let expected = fixture.root
            .appending(path: GeneratedTestArchive.folderName)
            .appending(path: "ThingTests.swift")
        #expect(url.path(percentEncoded: false) == expected.path(percentEncoded: false))
        withExtendedLifetime(fixture) {}
    }

    @Test func aRejectedReplyIsStillKept() throws {
        let fixture = try Fixture()
        try fixture.write("Thing.swift", "struct Thing {}")
        let subject = TestSubject.standalone(
            try StandaloneFile(url: fixture.root.appending(path: "Thing.swift"))
        )

        let url = try GeneratedTestArchive().saveUnusable(
            "I can't write a test for this.",
            for: subject,
            reason: .unparsed
        )

        #expect(url.lastPathComponent == "ThingTests-unparsed.txt")
        #expect(try String(contentsOf: url, encoding: .utf8) == "I can't write a test for this.")
        withExtendedLifetime(fixture) {}
    }

    @Test func aRunThatStoppedPartwayIsStillKept() throws {
        let fixture = try Fixture()
        try fixture.write("Thing.swift", "struct Thing {}")
        let subject = TestSubject.standalone(
            try StandaloneFile(url: fixture.root.appending(path: "Thing.swift"))
        )

        let url = try GeneratedTestArchive().saveUnusable(
            "import Testing\n@Suite struct ThingTe",
            for: subject,
            reason: .partial
        )

        #expect(url.lastPathComponent == "ThingTests-partial.txt")
        withExtendedLifetime(fixture) {}
    }
}
