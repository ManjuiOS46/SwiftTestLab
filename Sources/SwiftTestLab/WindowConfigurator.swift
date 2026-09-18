//
//  WindowConfigurator.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import AppKit
import SwiftUI

/// Keeps the window inside the part of the screen you can actually reach.
///
/// SwiftUI sizes a window to its content's ideal height, and a ScrollView's ideal
/// height is its whole content — so a long source file asked for a window taller
/// than the display, putting the footer underneath the Dock or off-screen entirely.
/// `visibleFrame` already excludes the Dock and the menu bar, so clamping to it is
/// the whole fix.
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let probe = NSView(frame: .zero)
        DispatchQueue.main.async { clamp(probe.window) }
        return probe
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { clamp(nsView.window) }
    }

    private func clamp(_ window: NSWindow?) {
        guard let window, let screen = window.screen ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        var frame = window.frame

        frame.size.width = min(frame.width, visible.width)
        frame.size.height = min(frame.height, visible.height)
        frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
        frame.origin.y = min(max(frame.minY, visible.minY), visible.maxY - frame.height)

        guard frame != window.frame else { return }
        window.setFrame(frame, display: true)
    }
}
