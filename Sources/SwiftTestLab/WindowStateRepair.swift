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
/// AppKit autosaves NSSplitView subview frames and restores them verbatim. If the
/// window was ever laid out taller than the display — which it was, before the
/// scroll views stopped reporting their whole contents as their ideal size — those
/// heights come back into a correctly sized window, and the split view ends up
/// taller than the window containing it. The panes then sit partly above and partly
/// below the visible area, so neither end can be scrolled to.
///
/// Run before any window is created.
enum WindowStateRepair {
    static func discardStateLargerThanTheScreen(
        defaults: UserDefaults = .standard,
        screenHeight: Double? = nil
    ) {
        let limit = screenHeight ?? Double(NSScreen.screens.map(\.frame.height).max() ?? 1_080)

        for (key, value) in defaults.dictionaryRepresentation() {
            guard key.hasPrefix("NSSplitView Subview Frames"),
                  let frames = value as? [String],
                  WindowFrameMath.exceeds(limit, frames: frames) else { continue }
            defaults.removeObject(forKey: key)
        }
    }
}
