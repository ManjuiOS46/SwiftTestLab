//
//  WindowBoundsLimiter.swift
//  SwiftTestLab
//
//  Created by Manju on 18/09/2026.
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
            // The backstop. SwiftUI resizes the window programmatically, which
            // ignores maxSize, so the only reliable guarantee is to notice it
            // happening and undo it. Acts only when the window is too big, so it
            // cannot fight a window that already fits.
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(windowResized),
                name: NSWindow.didResizeNotification,
                object: nil
            )
        }

        @objc private func windowResized(_ note: Notification) {
            guard let resized = note.object as? NSWindow, resized === window else { return }
            apply()
        }

        nonisolated deinit { NotificationCenter.default.removeObserver(self) }

        /// What the app opens at when nothing better is remembered.
        static let preferredSize = NSSize(width: 1_180, height: 760)

        /// Developer aid: records any view laid out larger than the window holding
        /// it. A scroll view's document is legitimately larger, so read the output
        /// with that in mind.
        static func dumpOversizedViews(in window: NSWindow) {
            guard let root = window.contentView else { return }
            let limit = window.frame.height
            var lines = ["WINDOW \(Int(window.frame.width))x\(Int(window.frame.height))"]

            func walk(_ view: NSView, depth: Int) {
                if view.frame.height > limit + 1 || view.frame.width > window.frame.width + 1 {
                    let indent = String(repeating: "  ", count: depth)
                    lines.append("\(indent)OVERSIZED \(type(of: view)) "
                                 + "\(Int(view.frame.width))x\(Int(view.frame.height))")
                }
                for subview in view.subviews { walk(subview, depth: depth + 1) }
            }
            walk(root, depth: 0)
            let destination = FileManager.default.temporaryDirectory
                .appending(path: "SwiftTestLab-layout.txt")
            try? lines.joined(separator: "\n")
                .write(to: destination, atomically: true, encoding: .utf8)
            FileHandle.standardError.write(
                Data("layout dump: \(destination.path(percentEncoded: false))\n".utf8)
            )
        }

        func attach(to window: NSWindow) {
            self.window = window
            window.minSize = NSSize(width: 820, height: 480)
            apply()

            // SwiftUI sizes a new window from its content's ideal width, and a
            // layout containing flexible frames asks for everything available —
            // so the window opens filling the screen. `.defaultSize` doesn't win
            // that argument. Setting the frame once, only when there's nothing
            // saved to restore, does.
            if CommandLine.arguments.contains("--dump-layout") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                    MainActor.assumeIsolated { Coordinator.dumpOversizedViews(in: window) }
                }
            }

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
