//
//  AssertionAuditTests.swift
//  SwiftTestLab
//
//  Created by Manju on 18/09/2026.
//

import Foundation
import Testing
@testable import SwiftTestLabKit

/// Every case here is real output from qwen3-coder:30b, not invented.
@Suite struct AssertionAuditTests {
    @Test func catchesComparingVoidToVoid() {
        let source = """
        @Suite struct AnnouncerTests {
            @Test func announcePrintsReady() {
                let announcer = Announcer()
                #expect(announcer.announce() == Void())
            }
        }
        """
        let found = AssertionAudit.vacuousAssertions(in: source)
        #expect(found.count == 1)
        #expect(found.first?.line == 4)
        #expect(found.first?.reason.contains("Void") == true)
    }

    /// `#expect(throws: Never.self)` is correct against a function that throws —
    /// the Swift Testing documentation teaches it as the success-path assertion.
    /// The source alone cannot tell the two apart, so it must not be flagged here.
    @Test func doesNotFlagANoThrowAssertionOnTheSourceAlone() {
        let source = """
        @Test func brewsWithBeans() {
            #expect(throws: Never.self) { try brew(true) }
        }
        """
        #expect(AssertionAudit.vacuousAssertions(in: source).isEmpty)
        #expect(AssertionAudit.vacuousAssertions(in: "XCTAssertNoThrow(try subject.run())").isEmpty)
    }

    /// When the call genuinely cannot throw, the compiler says so, and that
    /// warning is what the judgement rests on.
    @Test func flagsANoThrowAssertionTheCompilerProvesPointless() {
        let source = """
        @Test func announcePrintsReady() {
            let announcer = Announcer()
            #expect(throws: Never.self) { try announcer.announce() }
        }
        """
        let warning = Diagnostic(
            file: "AnnouncerTests.swift",
            line: 3,
            column: 41,
            severity: .warning,
            message: "no calls to throwing functions occur within 'try' expression"
        )

        let found = AssertionAudit.vacuousAssertions(
            in: source,
            confirmedBy: [warning],
            inFileNamed: "AnnouncerTests.swift"
        )
        #expect(found.count == 1)
        #expect(found.first?.line == 3)
        #expect(found.first?.reason.contains("compiler reports") == true)
    }

    @Test func findsTheAssertionWhenTheWarningPointsAtALineBelowIt() {
        let source = """
        @Test func announcePrintsReady() {
            #expect(throws: Never.self) {
                try announcer.announce()
            }
        }
        """
        let warning = Diagnostic(
            file: "T.swift",
            line: 3,
            column: 9,
            severity: .warning,
            message: "no calls to throwing functions occur within 'try' expression"
        )

        let found = AssertionAudit.vacuousAssertions(in: source, confirmedBy: [warning])
        #expect(found.count == 1)
        #expect(found.first?.line == 2)
    }

    @Test func ignoresWarningsFromOtherFiles() {
        let source = "#expect(throws: Never.self) { try x.f() }"
        let warning = Diagnostic(
            file: "SomebodyElsesTests.swift",
            line: 1,
            column: 1,
            severity: .warning,
            message: "no calls to throwing functions occur within 'try' expression"
        )

        #expect(
            AssertionAudit.vacuousAssertions(
                in: source,
                confirmedBy: [warning],
                inFileNamed: "MyTests.swift"
            ).isEmpty
        )
    }

    @Test func ignoresUnrelatedWarnings() {
        let source = "#expect(throws: Never.self) { try x.f() }"
        let warning = Diagnostic(
            file: "T.swift",
            line: 1,
            column: 1,
            severity: .warning,
            message: "variable 'y' was never used"
        )
        #expect(AssertionAudit.vacuousAssertions(in: source, confirmedBy: [warning]).isEmpty)
    }

    @Test func catchesAssertingAValueIsItsOwnType() {
        let source = "    #expect(viewController is SecondViewController)"
        #expect(AssertionAudit.vacuousAssertions(in: source).count == 1)
    }

    @Test func catchesAlwaysTrueAssertions() {
        let source = """
        #expect(true)
        #expect(Bool(true))
        XCTAssertTrue(true)
        """
        #expect(AssertionAudit.vacuousAssertions(in: source).count == 3)
    }

    @Test func leavesRealAssertionsAlone() {
        let source = """
        @Suite struct SliderTests {
            @Test func clampsAboveTheRange() {
                #expect(Slider(value: 2).value == 1)
            }

            @Test func rejectsAnEmptyBasket() {
                #expect(throws: PricingError.emptyBasket) { try pricer.total(for: []) }
            }

            @Test func unwrapsWhatShouldBeThere() throws {
                let brand = try #require(catalogue.brand(id: "a"))
                #expect(brand.name == "Acme")
            }
        }
        """
        #expect(AssertionAudit.vacuousAssertions(in: source).isEmpty)
    }

    @Test func reportsEachOffendingLineOnce() {
        let source = """
        #expect(a.run() == Void())
        #expect(b.run() == Void())
        """
        let found = AssertionAudit.vacuousAssertions(in: source)
        #expect(found.map(\.line) == [1, 2])
    }

    @Test func aGeneratedTestCanAuditItself() {
        let test = GeneratedTest(
            source: "@Test func x() { #expect(thing.go() == Void()) }\n",
            suiteName: "T",
            fileName: "T.swift"
        )
        #expect(test.vacuousAssertions.count == 1)
    }
}
