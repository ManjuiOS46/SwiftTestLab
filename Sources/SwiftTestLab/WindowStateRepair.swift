//
//  WindowStateRepair.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import AppKit
import Foundation
import SwiftTestLabKit

/// Throws away restored window state that no longer fits on a screen.
///
/// AppKit autosaves window and NSSplitView geometry and restores it verbatim. This
/// app once sized its window from its content — a SwiftUI ScrollView reports its
/// whole contents as its ideal size — and grew past the display. Those heights then
/// came back into a correctly sized window, leaving the split view taller than the
/// window containing it: both panes sat partly above and partly below the visible
/// area, and neither end could be scrolled to.
///
/// Runs once, before any window is created. Nothing clamps at layout time, because
/// resizing a window from inside a layout pass just causes another layout pass.
enum WindowStateRepair {
    static func discardStateLargerThanTheScreen(
        defaults: UserDefaults = .standard,
        screenHeight: Double? = nil
    ) {
        let limit = screenHeight ?? Double(NSScreen.screens.map(\.frame.height).max() ?? 1_080)

        for (key, value) in defaults.dictionaryRepresentation() {
            if key.hasPrefix("NSSplitView Subview Frames"),
               let frames = value as? [String],
               WindowFrameMath.exceeds(limit, frames: frames) {
                defaults.removeObject(forKey: key)
            }

            if key.hasPrefix("NSWindow Frame"),
               let frame = value as? String,
               WindowFrameMath.windowIsTallerThanItsScreen(frame) {
                defaults.removeObject(forKey: key)
            }
        }
    }
}
