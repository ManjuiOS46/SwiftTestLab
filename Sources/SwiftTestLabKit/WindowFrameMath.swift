//
//  WindowFrameMath.swift
//  SwiftTestLab
//
//  Created by Manju on 18/09/2026.
//

import Foundation

/// Parsing for AppKit's autosaved split-view frames, kept here so it can be tested.
///
/// An entry looks like `"0.000000, 0.000000, 300.000000, 1627.000000, NO, NO"`.
public enum WindowFrameMath {
    public static func height(inAutosavedFrame frame: String) -> Double? {
        let numbers = frame
            .split(separator: ",")
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard numbers.count >= 4 else { return nil }
        return numbers[3]
    }

    /// True when restoring this state would lay content out taller than the display.
    public static func exceeds(_ limit: Double, frames: [String]) -> Bool {
        frames.contains { (height(inAutosavedFrame: $0) ?? 0) > limit }
    }

    /// AppKit stores a window frame as `"x y w h screenX screenY screenW screenH"`,
    /// so the frame carries the screen it was saved against and can check itself.
    public static func windowIsTallerThanItsScreen(_ frame: String) -> Bool {
        let numbers = frame.split(separator: " ").compactMap { Double($0) }
        guard numbers.count >= 8 else { return false }
        let windowHeight = numbers[3]
        let screenHeight = numbers[7]
        return screenHeight > 0 && windowHeight > screenHeight
    }
}
