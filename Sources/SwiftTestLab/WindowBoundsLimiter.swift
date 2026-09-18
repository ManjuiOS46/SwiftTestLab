//
//  WindowBoundsLimiter.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import AppKit
import SwiftUI

/// Tells AppKit the window may never be larger than the screen, once.
///
/// This is a constraint, not a correction: `maxSize` is enforced by the window
/// itself, so no matter what any view asks for, the window can't grow past the
/// usable screen. Earlier attempts resized the window from inside a layout pass,
/// which only caused another layout pass.
struct WindowBoundsLimiter: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let probe = NSView(frame: .zero)
        DispatchQueue.main.async { [weak probe] in
            MainActor.assumeIsolated {
                guard let window = probe?.window else { return }
                context.coordinator.attach(to: window)
            }
        }
        return probe
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    @MainActor final class Coordinator {
        private weak var window: NSWindow?

        init() {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(screensChanged),
                name: NSApplication.didChangeScreenParametersNotification,
                object: nil
            )
        }

        nonisolated deinit { NotificationCenter.default.removeObserver(self) }

        /// What the app opens at when nothing better is remembered.
        static let preferredSize = NSSize(width: 1_180, height: 760)

        func attach(to window: NSWindow) {
            self.window = window
            window.minSize = NSSize(width: 820, height: 480)
            apply()

            // SwiftUI sizes a new window from its content's ideal width, and a
            // layout containing flexible frames asks for everything available —
            // so the window opens filling the screen. `.defaultSize` doesn't win
            // that argument. Setting the frame once, only when there's nothing
            // saved to restore, does.
            guard !WindowStateRepair.hasUsableSavedFrame else { return }
            openAtPreferredSize(window)
        }

        private func openAtPreferredSize(_ window: NSWindow) {
            guard let screen = window.screen ?? NSScreen.main else { return }
            let usable = screen.visibleFrame
            let size = NSSize(
                width: min(Self.preferredSize.width, usable.width),
                height: min(Self.preferredSize.height, usable.height)
            )
            window.setFrame(
                NSRect(
                    x: usable.midX - size.width / 2,
                    y: usable.midY - size.height / 2,
                    width: size.width,
                    height: size.height
                ),
                display: true
            )
        }

        @objc private func screensChanged() { apply() }

        private func apply() {
            guard let window, let screen = window.screen ?? NSScreen.main else { return }
            let usable = screen.visibleFrame

            window.maxSize = usable.size

            // If it is already too big — restored from an earlier session, say —
            // bring it back once. Not on every layout pass.
            var frame = window.frame
            guard frame.width > usable.width || frame.height > usable.height
                    || !usable.contains(frame.origin) else { return }

            frame.size.width = min(frame.width, usable.width)
            frame.size.height = min(frame.height, usable.height)
            frame.origin.x = min(max(frame.minX, usable.minX), usable.maxX - frame.width)
            frame.origin.y = min(max(frame.minY, usable.minY), usable.maxY - frame.height)
            window.setFrame(frame, display: true)
        }
    }
}
