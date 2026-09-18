//
//  RunView.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import SwiftTestLabKit
import SwiftUI

struct RunView: View {
    @Environment(AppModel.self) private var model
    @State private var pane: Pane = .test

    enum Pane: String, CaseIterable, Identifiable {
        case problems = "Problems"
        case test = "Test file"
        case output = "Raw output"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            VStack(alignment: .leading, spacing: 14) {
                if let runError = model.runError {
                    Notice(
                        symbol: "exclamationmark.octagon.fill",
                        tint: .red,
                        title: "Run stopped",
                        message: runError
                    )
                }
                if let report = model.report {
                    ResultCard(report: report)
                } else if model.phase == .accepted, let url = model.acceptedURL {
                    Notice(
                        symbol: "checkmark.circle.fill",
                        tint: .green,
                        title: "Written to \(url.lastPathComponent)",
                        message: url.path(percentEncoded: false),
                        actionTitle: "Reveal in Finder",
                        action: model.revealAcceptedFile
                    )
                }

                Picker("", selection: $pane) {
                    ForEach(panes) { pane in
                        Text(pane == .problems && problemCount > 0
                             ? "Problems (\(problemCount))"
                             : pane.rawValue)
                            .tag(pane)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 380)

                switch pane {
                case .problems:
                    ProblemsPane(diagnostics: model.report?.diagnostics ?? [])
                case .test:
                    CodePane(
                        text: model.modelOutput,
                        followsTail: model.phase == .generating,
                        placeholder: "The test file will appear here as it's written."
                    )
                case .output:
                    CodePane(
                        text: model.buildLog,
                        followsTail: true,
                        placeholder: "swift build and swift test output will stream here."
                    )
                }
            }
            .padding(16)

            Divider()
            footer
        }
        .background(Color.canvas)
        .onChange(of: model.phase) {
            switch model.phase {
            case .verifying: pane = .output
            case .finished: pane = problemCount > 0 ? .problems : .test
            default: break
            }
        }
    }

    private var panes: [Pane] {
        problemCount > 0 ? Pane.allCases : [.test, .output]
    }

    private var problemCount: Int {
        model.report?.errors.count ?? 0
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(model.subject?.fileName ?? "—")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                ProviderChip()
            }
            StageTrack(states: stages)
            if let location = locationLine {
                Text(location)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
        .padding(16)
    }

    /// Where the file is right now, and where it would go — the two things people
    /// ask about a generated file.
    private var locationLine: String? {
        if let accepted = model.acceptedURL {
            return "Written to \(accepted.path(percentEncoded: false))"
        }
        if model.generatedTest != nil {
            if let destination = model.destinationPath {
                return "Not written yet · Accept would write it to \(destination)"
            }
            return "Not written yet · Accept asks you where to save it"
        }
        if let scratch = model.scratchPath {
            return "Building in \(scratch)"
        }
        return nil
    }

    private var stages: [(title: String, state: StageTrack.State)] {
        let report = model.report
        let generate: StageTrack.State = switch model.phase {
        case .generating: model.runError == nil ? .active : .failed
        case .start, .ready: .pending
        case .failed: model.modelOutput.isEmpty ? .failed : .done
        default: .done
        }
        let build: StageTrack.State = {
            if let report { return report.compiled ? .done : .failed }
            if model.stage == .building { return .active }
            return .pending
        }()
        let run: StageTrack.State = {
            guard let report else { return model.stage == .running ? .active : .pending }
            if !report.compiled { return .skipped }
            return report.passed ? .done : .failed
        }()
        return [("Generate", generate), ("Build", build), ("Run", run)]
    }

    @ViewBuilder
    private var footer: some View {
        HStack(spacing: 12) {
            if model.phase == .accepted {
                Button("Generate Another") { model.resetRun() }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                Button("Reveal in Finder") { model.revealAcceptedFile() }
                Spacer()
            } else if model.isRunning {
                Button("Cancel", role: .cancel) { model.cancel() }
                    .controlSize(.large)
                Text("Cancelling stops the build and deletes the scratch copy. Nothing is written either way.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
            } else if model.phase == .failed {
                Button("Try Again") { model.resetRun() }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                Button("Copy Test") { model.copyTestToClipboard() }
                    .disabled(model.generatedTest == nil)
                Text("What was generated is still above — nothing was written to your files.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                if let report = model.report {
                    if report.passed {
                        Button("Review & Accept") { model.showingDiff = true }
                            .controlSize(.large)
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.defaultAction)
                            .disabled(!model.canAccept)
                    } else {
                        Button("Review & Accept Anyway") { model.showingDiff = true }
                            .controlSize(.large)
                            .disabled(!model.canAccept)
                    }
                }
                Button("Copy Test") { model.copyTestToClipboard() }
                    .disabled(model.generatedTest == nil)
                Button("Start Over") { model.resetRun() }
                if !model.canAccept {
                    Text("A test that doesn't compile is never written.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(16)
    }
}

private struct ResultCard: View {
    let report: VerificationReport

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 22))
                .foregroundStyle(tint)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(report.headline)
                    .font(.system(size: 15, weight: .semibold))
                Text(report.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(tint.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(tint.opacity(0.22), lineWidth: 1)
        )
    }

    private var symbol: String {
        switch report.outcome {
        case .passed: "checkmark.seal.fill"
        case .compileFailed: "xmark.octagon.fill"
        case .testsFailed: "exclamationmark.triangle.fill"
        case .noTestsRan: "questionmark.circle.fill"
        case .timedOut: "clock.badge.exclamationmark.fill"
        }
    }

    private var tint: Color {
        switch report.outcome {
        case .passed: .green
        case .compileFailed: .red
        case .testsFailed, .timedOut: .orange
        case .noTestsRan: .yellow
        }
    }
}


/// The lines of the build log that actually say what's wrong.
private struct ProblemsPane: View {
    let diagnostics: [Diagnostic]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(diagnostics) { diagnostic in
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: diagnostic.severity.symbolName)
                            .font(.system(size: 11))
                            .foregroundStyle(diagnostic.severity == .error ? .red : .orange)
                            .frame(width: 14)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(diagnostic.message)
                                .font(.system(size: 12))
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(diagnostic.location)
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    if diagnostic != diagnostics.last { Divider().padding(.leading, 37) }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.editor)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.hairline, lineWidth: 1)
        )
    }
}
