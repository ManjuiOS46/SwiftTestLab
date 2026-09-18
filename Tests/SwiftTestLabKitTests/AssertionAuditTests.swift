//
//  AssertionAuditTests.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
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

    /// The one the prompt explicitly forbids, which the model wrote anyway.
    @Test func catchesAssertingANonThrowingCallDoesNotThrow() {
        let source = """
        @Test func announcePrintsReady() {
            let announcer = Announcer()
            #expect(throws: Never.self) { try announcer.announce() }
        }
        """
        let found = AssertionAudit.vacuousAssertions(in: source)
        #expect(found.count == 1)
        #expect(found.first?.reason.contains("doesn't throw") == true)
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

    @Test func catchesXCTAssertNoThrow() {
        #expect(AssertionAudit.vacuousAssertions(in: "XCTAssertNoThrow(subject.run())").count == 1)
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
