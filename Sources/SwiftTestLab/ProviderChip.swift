//
//  ProviderChip.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import SwiftTestLabKit
import SwiftUI

/// Shows which model is about to be used, and lets it be changed without a trip
/// to Settings. Open models get the same billing as hosted ones: none.
struct ProviderChip: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Menu {
            Section("Anthropic") {
                ForEach(ProviderConfiguration.anthropicModels, id: \.self) { name in
                    Button {
                        model.anthropicModel = name
                        model.providerKind = .anthropic
                    } label: {
                        if isCurrent(.anthropic, name) { Label(name, systemImage: "checkmark") }
                        else { Text(name) }
                    }
                }
            }

            Section(openModelSectionTitle) {
                if model.availableOpenModels.isEmpty {
                    Button("Find models…") {
                        model.providerKind = .openAICompatible
                        model.probeOpenEndpoint()
                    }
                } else {
                    ForEach(model.availableOpenModels, id: \.self) { name in
                        Button {
                            model.openModel = name
                            model.providerKind = .openAICompatible
                        } label: {
                            if isCurrent(.openAICompatible, name) {
                                Label(name, systemImage: "checkmark")
                            } else {
                                Text(name)
                            }
                        }
                    }
                }
            }

            Divider()
            Button("Settings…") { openSettings() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: model.providerKind.symbolName)
                    .font(.system(size: 11))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                if model.providerKind == .openAICompatible && model.configuration.isLocal {
                    StatusPill(text: "free", tint: .green)
                }
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .disabled(model.isRunning)
        .help(model.configuration.endpointDescription)
    }

    private var label: String {
        let name = model.configuration.model
        let shown = name.isEmpty ? "No model" : name
        return "\(model.providerKind.displayName) · \(shown)"
    }

    private var openModelSectionTitle: String {
        let runtime = LocalRuntime.named(matching: model.openBaseURL)?.name
        return runtime ?? "Open model"
    }

    private func isCurrent(_ kind: ProviderKind, _ name: String) -> Bool {
        model.providerKind == kind && model.configuration.model == name
    }
}
