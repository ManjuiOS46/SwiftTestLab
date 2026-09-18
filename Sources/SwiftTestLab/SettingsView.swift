//
//  SettingsView.swift
//  SwiftTestLab
//
//  Created by Manju on 18/09/2026.
//

import SwiftTestLabKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var anthropicKeyEntry = ""
    @State private var openKeyEntry = ""

    var body: some View {
        @Bindable var model = model

        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Where tests come from")
                Picker("", selection: $model.providerKind) {
                    ForEach(ProviderKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text(model.providerKind.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            switch model.providerKind {
            case .anthropic:
                anthropicSection
            case .openAICompatible:
                openModelSection
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 520, height: 470, alignment: .topLeading)
        .onAppear { model.refreshCredentialStatus() }
    }

    // MARK: - Anthropic

    private var anthropicSection: some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Model")
                Picker("", selection: $model.anthropicModel) {
                    ForEach(ProviderConfiguration.anthropicModels, id: \.self) { Text($0).tag($0) }
                    if !ProviderConfiguration.anthropicModels.contains(model.anthropicModel) {
                        Text(model.anthropicModel).tag(model.anthropicModel)
                    }
                }
                .labelsHidden()
                TextField("Or type a model ID", text: $model.anthropicModel)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(
                    title: "API key",
                    trailing: model.hasAnthropicKey ? "in Keychain" : "not set"
                )
                SecureField("sk-ant-…", text: $anthropicKeyEntry)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Button(model.hasAnthropicKey ? "Replace" : "Save") {
                        model.saveCredential(anthropicKeyEntry, for: .anthropic)
                        anthropicKeyEntry = ""
                    }
                    .disabled(anthropicKeyEntry.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button("Remove", role: .destructive) {
                        model.removeCredential(for: .anthropic)
                        anthropicKeyEntry = ""
                    }
                    .disabled(!model.hasAnthropicKey)
                }
                Text("Stored in the login Keychain. Never written to disk in plain text, never logged, and never included in an error message.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Open models

    private var openModelSection: some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(title: "Endpoint")
                HStack(spacing: 8) {
                    Menu {
                        ForEach(LocalRuntime.all) { runtime in
                            Button(runtime.name) { model.useRuntime(runtime) }
                        }
                    } label: {
                        Text(LocalRuntime.named(matching: model.openBaseURL)?.name ?? "Custom")
                    }
                    .frame(width: 130)

                    TextField("http://localhost:11434/v1", text: $model.openBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { model.probeOpenEndpoint() }

                    Button("Check") { model.probeOpenEndpoint() }
                }
                connectionStatus
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(
                    title: "Model",
                    trailing: model.availableOpenModels.isEmpty
                        ? nil
                        : "\(model.availableOpenModels.count) available"
                )
                if model.availableOpenModels.isEmpty {
                    TextField("Model name", text: $model.openModel)
                        .textFieldStyle(.roundedBorder)
                } else {
                    Picker("", selection: $model.openModel) {
                        ForEach(model.availableOpenModels, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                }
                Text("A coding-tuned model does markedly better here than a general chat model of the same size.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !model.configuration.isLocal {
                VStack(alignment: .leading, spacing: 8) {
                    SectionHeader(
                        title: "API key (remote endpoints only)",
                        trailing: model.hasOpenModelKey ? "in Keychain" : "not set"
                    )
                    SecureField("Bearer token", text: $openKeyEntry)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button(model.hasOpenModelKey ? "Replace" : "Save") {
                            model.saveCredential(openKeyEntry, for: .openAICompatible)
                            openKeyEntry = ""
                        }
                        .disabled(openKeyEntry.trimmingCharacters(in: .whitespaces).isEmpty)
                        Button("Remove", role: .destructive) {
                            model.removeCredential(for: .openAICompatible)
                            openKeyEntry = ""
                        }
                        .disabled(!model.hasOpenModelKey)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var connectionStatus: some View {
        switch model.connection {
        case .unknown:
            Text("Not checked yet.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        case .checking:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small).scaleEffect(0.7)
                Text("Checking…").font(.system(size: 11)).foregroundStyle(.secondary)
            }
        case .reachable(let count):
            Label(
                "Reachable — \(count) model\(count == 1 ? "" : "s") loaded",
                systemImage: "checkmark.circle.fill"
            )
            .font(.system(size: 11))
            .foregroundStyle(.green)
        case .unreachable(let reason):
            Label(reason, systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
