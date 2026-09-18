//
//  SystemPrompt.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import Foundation

/// The instructions sent with every request. Kept as plain text in one place so
/// the UI can show the user exactly what will be sent before anything is sent.
public enum SystemPrompt {
    public static func text(for framework: TestFramework) -> String {
        """
        You are writing a unit test for one Swift file in a Swift Package. \
        The package's tests use \(framework.displayName).

        \(frameworkGuidance(for: framework))

        Rules:

        1. Return one complete, compilable test file and nothing else. No prose, \
        no explanation, no markdown fences — just Swift source, starting with its imports.
        2. Cover the happy path, boundary values and error paths.
        3. Never refer to anything that isn't in the file you were given or the standard \
        library. Do not invent a protocol, type, initialiser or property to make the \
        subject testable. If it depends on a protocol, write a fake by implementing that \
        protocol. If it depends on a concrete type or calls static methods, there is no \
        seam — test what can be reached without one and leave the rest alone. No mocking \
        framework is available.
        4. Never force-unwrap, never use `try!`, and never index a collection directly. \
        A trap takes down the whole suite, not one test. Use optional binding, \
        `first`/`last`, and the framework's own unwrapping and error assertions.
        5. Never invent an expected value. If the code does not tell you what a string, \
        default or identifier should be, assert something derivable instead — that a value \
        is not nil, that a count holds, that two calls agree with each other.
        6. Assert the behaviour the code should have, not what it happens to do. If a line \
        looks like a bug, write the test that documents the correct behaviour.
        7. Test only what a test target can reach: public and internal declarations. \
        Ignore anything private or fileprivate.
        8. Every assertion must be capable of failing. Do not assert that a value is the \
        type it was just constructed as, that a non-optional is not nil, that a constant \
        equals itself, or that calling a function "does not throw" when it isn't declared \
        to throw. An assertion that cannot fail is not a test.
        9. Prefer a few real tests to many weak ones. If the file holds no behaviour a \
        unit test can observe — a view's body, a data holder with no logic — write only \
        the assertions that can genuinely fail and stop there. A short honest suite is \
        the right answer; padding it out is not.
        """
    }

    private static func frameworkGuidance(for framework: TestFramework) -> String {
        switch framework {
        case .swiftTesting:
            """
            Use Swift Testing: `import Testing`, a `@Suite` struct with `@Test` functions, and \
            `#expect(...)` for assertions.

            Getting the mechanics right matters as much as the assertions:
            - If anything in the test throws, mark that test function `throws` and call it \
            with `try`. A throwing call in a non-throwing test does not compile.
            - `try #require(...)` is only for unwrapping an optional, or stopping a test that \
            cannot continue. Never wrap a non-optional value in it.
            - Use `#expect(throws: SomeError.self)` or `#expect(throws: SomeError.someCase)` \
            for error paths, with a closure that calls the throwing code.
            - Mark a test `async` only where the code under test is async.
            - A fake that records calls or varies its answers must be a `final class`, not a \
            struct: a test holds it in a `let`, and a `let` struct cannot be mutated.

            The single most common way this goes wrong: a `@Test` function whose body \
            contains `try` anywhere must itself be declared `throws`. Check every test \
            function for this before you answer.

            The shape to follow — a whole file, imports included:

            import Testing
            @testable import TheModule

            @Suite struct ThingTests {
                @Test func addsUpTheParts() throws {
                    let thing = Thing(source: FakeSource())
                    #expect(try thing.total(for: parts) == 200)
                }

                @Test func rejectsAnEmptyInput() {
                    let thing = Thing(source: FakeSource())
                    #expect(throws: ThingError.empty) { try thing.total(for: []) }
                }
            }

            private final class FakeSource: Source {
                var answer = 0
                func value(for key: String) -> Int { answer }
            }

            Do not use XCTest.
            """
        case .xctest:
            """
            Use XCTest: `import XCTest`, a `final class` inheriting `XCTestCase`, and test \
            methods named `testSomething()`.

            Getting the mechanics right matters as much as the assertions:
            - If anything in the test throws, declare the method `func testX() throws` and \
            call it with `try`. A throwing call in a non-throwing method does not compile.
            - Use `try XCTUnwrap(...)` instead of force-unwrapping, and only on optionals.
            - Use `XCTAssertThrowsError` for error paths, checking the error in its closure.
            - A fake that records calls or varies its answers must be a `final class`, not a \
            struct: a test holds it in a `let`, and a `let` struct cannot be mutated.

            Do not use Swift Testing macros.
            """
        }
    }
}

/// Everything that will go over the wire for one generation, assembled up front
/// so it can be reviewed.
public struct GenerationRequest: Sendable {
    public let model: String
    public let endpointDescription: String
    public let systemPrompt: String
    public let userMessage: String
    public let subjectName: String
    public let subjectBaseName: String
    public let framework: TestFramework

    public init(
        model: String,
        endpointDescription: String,
        systemPrompt: String,
        userMessage: String,
        subjectName: String,
        subjectBaseName: String,
        framework: TestFramework
    ) {
        self.model = model
        self.endpointDescription = endpointDescription
        self.systemPrompt = systemPrompt
        self.userMessage = userMessage
        self.subjectName = subjectName
        self.subjectBaseName = subjectBaseName
        self.framework = framework
    }

    /// Rough character count of what will be sent — enough for the preview to be
    /// honest about size without pretending to be a tokenizer.
    public var characterCount: Int { systemPrompt.count + userMessage.count }
}

public struct PromptBuilder: Sendable {
    public init() {}

    public func build(
        configuration: ProviderConfiguration,
        subject: TestSubject
    ) throws -> GenerationRequest {
        let source = try subject.source()
        let framework = subject.framework

        return GenerationRequest(
            model: configuration.model,
            endpointDescription: configuration.endpointDescription,
            systemPrompt: SystemPrompt.text(for: framework),
            userMessage: Self.userMessage(for: subject, source: source),
            subjectName: subject.fileName,
            subjectBaseName: subject.baseName,
            framework: framework
        )
    }

    static func userMessage(for subject: TestSubject, source: String) -> String {
        switch subject {
        case .inPackage(let package, let file):
            """
            Package: \(package.name)
            Module under test: \(file.moduleName)
            File: \(file.relativePath)
            Test target: \(package.testTarget.name) (\(package.testTarget.framework.displayName))

            The test file will live in \(package.testTarget.relativeDirectory)/ and must \
            `@testable import \(file.moduleName)`.

            Write the test file for this source:

            \(source)
            """
        case .standalone(let file):
            """
            File: \(file.fileName)

            This file is being tested on its own. It is compiled as the only file in a \
            module named `\(file.moduleName)`, with no access to the rest of the \
            project it came from, so use only what this file and the Swift standard \
            library or Foundation provide. The test must \
            `@testable import \(file.moduleName)`.

            Write the test file for this source:

            \(source)
            """
        }
    }
}
