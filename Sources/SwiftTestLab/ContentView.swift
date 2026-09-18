//
//  ContentView.swift
//  SwiftTestLab
//
//  Created by Manju on 18/09/2026.
//

import SwiftTestLabKit
import SwiftUI

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        @Bindable var model = model

        NavigationSplitView {
            WorkspaceSidebar()
                .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 420)
        } detail: {
            DetailView()
        }
        // A floor on width matters for more than looks: SwiftUI computes the
        // content's minimum height by proposing a width of zero, and text marked
        // `.fixedSize(vertical:)` then wraps to one character per line and reports
        // a minimum height of thousands of points. Giving it a real width to wrap
        // at keeps that number sane.
        .frame(minWidth: 900, minHeight: 500)
        .background(WindowBoundsLimiter())
        // Opaque, so scrolled content can never appear behind the window controls.
        .toolbarBackground(.visible, for: .windowToolbar)
        .toolbar { toolbarContent }
        .sheet(isPresented: $model.showingPromptPreview) { PromptPreviewSheet() }
        .sheet(isPresented: $model.showingDiff) { DiffSheet() }
        .alert(
            "Something went wrong",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            ),
            presenting: model.errorMessage
        ) { _ in
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: { message in
            Text(message)
        }
        .onAppear {
            model.refreshCredentialStatus()
            // Always probe: knowing a local model is available is what turns
            // "no API key" into an offer rather than a wall.
            model.probeOpenEndpoint()
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Menu {
                Button("Open Swift Package…") { model.choosePackage() }
                Button("Open Single Swift File…") { model.chooseFile() }
            } label: {
                Label("Open", systemImage: "plus")
            }
            .disabled(model.isRunning)
        }

        ToolbarItem {
            Button {
                openSettings()
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .help("Provider, model and API keys")
        }

        // Labelled and prominent, and in the toolbar rather than only in a footer:
        // a window can be taller than the screen, and then a footer is unreachable.
        ToolbarItem(placement: .primaryAction) {
            if model.isRunning {
                Button(role: .cancel) {
                    model.cancel()
                } label: {
                    Label("Cancel", systemImage: "stop.fill")
                }
                .labelStyle(.titleAndIcon)
                .keyboardShortcut(".", modifiers: .command)
            } else {
                Button {
                    model.reviewPrompt()
                } label: {
                    Label("Review & Generate", systemImage: "wand.and.stars")
                }
                .labelStyle(.titleAndIcon)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("r", modifiers: .command)
                .disabled(!model.canGenerate)
                .help(model.blockingReason ?? "Show exactly what will be sent, then generate (⌘R)")
            }
        }
    }
}
