//
//  SwiftTestLabApp.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import AppKit
import SwiftUI

@main
struct SwiftTestLabApp: App {
    @State private var model = AppModel()

    init() {
        // Before any window exists: restored split-view geometry from an oversized
        // window would otherwise be applied to a correctly sized one.
        WindowStateRepair.discardStateLargerThanTheScreen()

        // Built as an SPM executable there is no app bundle, so the process has to
        // ask for a Dock icon and a menu bar itself. Harmless inside a bundle too.
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .task {
                    NSApplication.shared.activate()
                    model.openFromCommandLine()
                }
        }
        .defaultSize(width: 1_180, height: 760)
        .defaultPosition(.center)
        // Content decides the window's *minimum* only. Under .automatic, SwiftUI
        // resizes the window to its content's ideal size whenever that changes —
        // which is how opening a file made the window thousands of points tall.
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open Swift Package…") { model.choosePackage() }
                    .keyboardShortcut("o")
                Button("Open Single Swift File…") { model.chooseFile() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
            }
            CommandMenu("Generate") {
                Button("Review & Generate…") { model.reviewPrompt() }
                    .disabled(!model.canGenerate)
                Button("Cancel Run") { model.cancel() }
                    .disabled(!model.isRunning)
                Divider()
                Button("Start Over") { model.resetRun() }
                    .disabled(model.isRunning)
            }
        }

        Settings {
            SettingsView()
                .environment(model)
        }
    }
}
