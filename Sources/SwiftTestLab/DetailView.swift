//
//  DetailView.swift
//  SwiftTestLab
//
//  Created by Manju on 18/09/2026.
//

import SwiftTestLabKit
import SwiftUI

struct DetailView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            switch model.phase {
            case .start:
                StartView()
            case .generating, .verifying, .finished, .failed, .accepted:
                RunView()
            case .ready:
                if model.subject != nil {
                    SubjectPane()
                } else {
                    ContentUnavailableView(
                        "Pick a file",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Choose a Swift file on the left to generate a test for it.")
                    )
                    .background(Color.canvas)
                }
            }
        }
    }
}

/// The idle screen: what would be sent, and the button that shows it to you first.
private struct SubjectPane: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            if let subject = model.subject {
                header(for: subject)
                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    if model.blockingReason != nil {
                        BlockedNotice()
                    }
                    if !model.subjectWarnings.isEmpty {
                        Notice(
                            symbol: "exclamationmark.triangle.fill",
                            tint: .orange,
                            title: "Heads up",
                            message: model.subjectWarnings.joined(separator: "\n\n")
                        )
                    }
                    SectionHeader(title: "Source", trailing: subject.locationDescription)
                    CodePane(text: (try? subject.source()) ?? "Couldn't read this file.")
                }
                .padding(16)

                Divider()
                footer
            }
        }
        .background(Color.canvas)
    }

    private func header(for subject: TestSubject) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(subject.fileName)
                    .font(.system(size: 17, weight: .semibold))
                Text(subject.contextDescription)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text("A test would `@testable import \(subject.moduleName)`")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            ProviderChip()
        }
        .padding(16)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("Review & Generate") { model.reviewPrompt() }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canGenerate)
            Text(model.canGenerate
                 ? "Nothing is sent until you've seen it."
                 : "Can't generate yet — see above.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(16)
    }
}


/// Says what's missing, and offers the shortest way out of it. When a local model
/// server is already running, that way out is free and one click.
struct BlockedNotice: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        if let reason = model.blockingReason {
            if model.providerKind == .anthropic && model.canOfferLocalModel {
                Notice(
                    symbol: "key.slash",
                    tint: .orange,
                    title: reason,
                    message: "\(model.localRuntimeName) is running on this Mac with \(model.availableOpenModels.count) models loaded. Using one costs nothing and sends nothing off the machine.",
                    actionTitle: "Use \(model.localRuntimeName)",
                    action: model.switchToLocalModel,
                    secondaryTitle: "Add a Key…",
                    secondaryAction: { openSettings() }
                )
            } else {
                Notice(
                    symbol: "exclamationmark.triangle.fill",
                    tint: .orange,
                    title: reason,
                    message: model.providerKind == .anthropic
                        ? "Add a key in Settings, or point SwiftTestLab at a model running on this Mac — Ollama, LM Studio, llama.cpp or vLLM."
                        : "Check the endpoint and pick a model in Settings.",
                    actionTitle: "Open Settings…",
                    action: { openSettings() }
                )
            }
        }
    }
}
