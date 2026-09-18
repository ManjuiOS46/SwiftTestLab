//
//  StartView.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import SwiftTestLabKit
import SwiftUI

struct StartView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SwiftTestLab")
                        .font(.system(size: 30, weight: .semibold))
                    Text("Writes one unit test for one Swift file — then compiles it and runs it, and shows you the result before you keep it.")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 14) {
                    ChoiceCard(
                        symbol: "shippingbox",
                        title: "Swift Package",
                        detail: "A folder with a Package.swift. Uses your own test target, matches the framework your tests already use, and can write the accepted test straight into it.",
                        buttonTitle: "Open Package…",
                        action: model.choosePackage
                    )
                    ChoiceCard(
                        symbol: "doc.text",
                        title: "Single Swift File",
                        detail: "Any .swift file on its own. Built in a throwaway package to verify it, so it works only if the file stands alone — no project types around it.",
                        buttonTitle: "Open File…",
                        action: model.chooseFile
                    )
                }

                Divider()

                HStack(alignment: .top, spacing: 36) {
                    Column(
                        title: "What it does",
                        symbol: "checkmark",
                        tint: .green,
                        items: [
                            "Shows the exact prompt before anything is sent",
                            "Builds and runs the test in a scratch copy",
                            "Gives you the raw compiler and test output",
                            "Writes nothing until you accept a diff",
                        ]
                    )
                    Column(
                        title: "What it deliberately doesn't",
                        symbol: "xmark",
                        tint: .secondary,
                        items: [
                            "No repair loop — a failing test is your call",
                            "No project sweep, no queue, no coverage",
                            "No Xcode projects or simulators",
                            "Never overwrites a test a human wrote",
                        ]
                    )
                }
            }
            .frame(maxWidth: 780, alignment: .leading)
            .padding(36)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .background(Color.canvas)
    }
}

private struct ChoiceCard: View {
    let symbol: String
    let title: String
    let detail: String
    let buttonTitle: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.system(size: 15, weight: .semibold))
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 6)
            Button(buttonTitle, action: action)
                .controlSize(.large)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 210, alignment: .topLeading)
        .card(fill: hovering ? Color.panel.opacity(0.7) : .panel)
        .onHover { hovering = $0 }
    }
}

private struct Column: View {
    let title: String
    let symbol: String
    let tint: Color
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: title)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Image(systemName: symbol)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(tint)
                        .frame(width: 11)
                    Text(item)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
