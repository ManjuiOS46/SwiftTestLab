//
//  WorkspaceSidebar.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import SwiftTestLabKit
import SwiftUI

struct WorkspaceSidebar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            switch model.workspace {
            case .package(let package):
                PackageHeader(package: package)
                Divider()
                List(model.visibleFiles, id: \.self, selection: $model.selectedFile) { file in
                    FileRow(file: file)
                        .tag(file)
                }
                .listStyle(.sidebar)
                .searchable(text: $model.fileFilter, placement: .sidebar, prompt: "Filter files")

            case .file(let file):
                StandaloneHeader(file: file)
                Spacer()

            case nil:
                Spacer()
                Text("Nothing open")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
    }
}

private struct FileRow: View {
    let file: SourceFile

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(file.fileName)
                .font(.system(size: 12.5))
            Text(file.relativePath)
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.head)
        }
        .padding(.vertical, 2)
    }
}

private struct PackageHeader: View {
    @Environment(AppModel.self) private var model
    let package: SwiftPackage

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: "shippingbox.fill")
                    .foregroundStyle(Color.accentColor)
                Text(package.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Button("Close") { model.closeWorkspace() }
                    .buttonStyle(.link)
                    .font(.system(size: 11))
                    .disabled(model.isRunning)
            }

            HStack(spacing: 6) {
                StatusPill(
                    text: "\(package.sourceFiles.count) files",
                    tint: .secondary
                )
                StatusPill(
                    text: package.testTarget.framework.displayName,
                    tint: .accentColor,
                    symbol: "checkmark.diamond.fill"
                )
            }
            .help("Detected because \(package.testTarget.frameworkEvidence)")

            Text(package.testTarget.relativeDirectory)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .truncationMode(.head)
        }
        .padding(12)
    }
}

private struct StandaloneHeader: View {
    @Environment(AppModel.self) private var model
    let file: StandaloneFile

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(Color.accentColor)
                Text(file.fileName)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Button("Close") { model.closeWorkspace() }
                    .buttonStyle(.link)
                    .font(.system(size: 11))
                    .disabled(model.isRunning)
            }

            StatusPill(text: "Standalone", tint: .orange, symbol: "square.dashed")

            Text(file.directory.path(percentEncoded: false))
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(2)
                .truncationMode(.head)

            Text("Built on its own as a module named \(StandaloneFile.moduleName). If it needs types from the rest of its project, the build will say so.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
    }
}
