//
//  WindowFrameMathTests.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import Foundation
import Testing
@testable import SwiftTestLabKit

@Suite struct WindowFrameMathTests {
    @Test func readsTheHeightOutOfAnAutosavedFrame() {
        #expect(
            WindowFrameMath.height(
                inAutosavedFrame: "0.000000, 0.000000, 300.000000, 1627.000000, NO, NO"
            ) == 1627
        )
    }

    @Test func ignoresEntriesItCannotRead() {
        #expect(WindowFrameMath.height(inAutosavedFrame: "nonsense") == nil)
        #expect(WindowFrameMath.height(inAutosavedFrame: "1, 2") == nil)
    }

    /// The real case: a 1627pt split view restored into a 760pt window on a 949pt
    /// screen, leaving both panes partly off-screen at each end.
    @Test func spotsStateTallerThanTheScreen() {
        let restored = [
            "0.000000, 0.000000, 300.000000, 1627.000000, NO, NO",
            "301.000000, 0.000000, 879.000000, 1627.000000, NO, NO",
        ]
        #expect(WindowFrameMath.exceeds(949, frames: restored))
    }

    @Test func leavesStateThatFitsAlone() {
        let healthy = [
            "0.000000, 0.000000, 300.000000, 700.000000, NO, NO",
            "301.000000, 0.000000, 879.000000, 700.000000, NO, NO",
        ]
        #expect(!WindowFrameMath.exceeds(949, frames: healthy))
    }
}
