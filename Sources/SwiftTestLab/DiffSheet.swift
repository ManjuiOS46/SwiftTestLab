//
//  DiffSheet.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import SwiftTestLabKit
import SwiftUI

struct DiffSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(model.diffLines) { line in
                        Text(line.text)
                            .font(.system(size: 11.5, design: .monospaced))
                            .foregroundStyle(color(for: line.kind))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 1)
                            .background(line.kind == .added ? Color.green.opacity(0.08) : .clear)
                    }
                }
                .padding(.vertical, 10)
                .textSelection(.enabled)
            }
            .background(Color.editor)

            Divider()
            footer
        }
        .frame(width: 840, height: 640)
        .background(Color.canvas)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(isSaveAs ? "Save this file?" : "Write this file?")
                .font(.system(size: 16, weight: .semibold))
            if let destination = model.destinationDescription {
                Text(destination)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Text(isSaveAs
                 ? "You'll be asked where to put it. It's a new file — nothing is merged."
                 : "A new file. If anything already exists at that path, the write is refused.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }

    private var footer: some View {
        HStack {
            if let report = model.report, !report.passed {
                Label("This test compiled but did not pass.", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
            }
            Spacer()
            Button("Cancel", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(isSaveAs ? "Save As…" : "Write File") { model.acceptTest() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }

    private var isSaveAs: Bool {
        guard let subject = model.subject, let test = model.generatedTest else { return false }
        return subject.destination(forTestFileNamed: test.fileName) == nil
    }

    private func color(for kind: DiffLine.Kind) -> Color {
        switch kind {
        case .header: .secondary
        case .hunk: .blue
        case .added: .primary
        }
    }
}
