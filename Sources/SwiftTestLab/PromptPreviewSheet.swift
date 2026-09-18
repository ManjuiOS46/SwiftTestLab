//
//  PromptPreviewSheet.swift
//  SwiftTestLab
//
//  Created by Manju on 18/09/2026.
//

import SwiftTestLabKit
import SwiftUI

/// Everything that will be sent, shown before it is sent. There is no path from
/// picking a file to calling a model that skips this screen.
struct PromptPreviewSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var pane: Pane = .system

    enum Pane: String, CaseIterable, Identifiable {
        case system = "System prompt"
        case message = "Message"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let request = model.pendingRequest {
                header(for: request)
                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    Picker("", selection: $pane) {
                        ForEach(Pane.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 280)

                    CodePane(text: pane == .system ? request.systemPrompt : request.userMessage)
                }
                .padding(16)

                Divider()
                footer
            } else {
                ProgressView().padding(40)
            }
        }
        .frame(width: 860, height: 640)
        .background(Color.canvas)
    }

    private func header(for request: GenerationRequest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This is what will be sent")
                .font(.system(size: 16, weight: .semibold))
            HStack(spacing: 6) {
                StatusPill(text: request.model, tint: .accentColor, symbol: "cpu")
                StatusPill(text: request.framework.displayName, tint: .secondary)
                StatusPill(text: "\(request.characterCount.formatted()) characters", tint: .secondary)
                if model.configuration.isLocal {
                    StatusPill(text: "stays on this Mac", tint: .green, symbol: "lock.fill")
                }
            }
            Text(request.endpointDescription)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    private var footer: some View {
        HStack {
            Text("Your API key is not part of this preview and is never logged.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Cancel", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("Send") { model.sendPendingRequest() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }
}
