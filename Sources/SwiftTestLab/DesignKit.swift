//
//  DesignKit.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import SwiftTestLabKit
import SwiftUI

// MARK: - Surfaces

extension ShapeStyle where Self == Color {
    /// Panel background — one step up from the window.
    static var panel: Color { Color(nsColor: .controlBackgroundColor) }
    /// Code and log background.
    static var editor: Color { Color(nsColor: .textBackgroundColor) }
    static var canvas: Color { Color(nsColor: .underPageBackgroundColor) }
    static var hairline: Color { Color(nsColor: .separatorColor) }
}

struct CardBackground: ViewModifier {
    var radius: CGFloat = 12
    var fill: Color = .panel

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.hairline, lineWidth: 1)
            )
    }
}

extension View {
    func card(radius: CGFloat = 12, fill: Color = .panel) -> some View {
        modifier(CardBackground(radius: radius, fill: fill))
    }
}

// MARK: - Text

struct SectionHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Pills

struct StatusPill: View {
    let text: String
    let tint: Color
    var symbol: String?

    var body: some View {
        HStack(spacing: 4) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 9, weight: .bold))
            }
            Text(text).font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(tint.opacity(0.14)))
        .foregroundStyle(tint)
    }
}

// MARK: - Stage track

/// Generate → Build → Run, so the pipeline is visible rather than implied.
struct StageTrack: View {
    enum State { case pending, active, done, failed, skipped }

    let states: [(title: String, state: State)]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(states.enumerated()), id: \.offset) { index, item in
                HStack(spacing: 6) {
                    icon(for: item.state)
                        .frame(width: 14, height: 14)
                    Text(item.title)
                        .font(.system(size: 12, weight: item.state == .active ? .semibold : .regular))
                        .foregroundStyle(color(for: item.state))
                }
                if index < states.count - 1 {
                    Rectangle()
                        .fill(Color.hairline)
                        .frame(height: 1)
                        .frame(maxWidth: 28)
                }
            }
        }
    }

    @ViewBuilder
    private func icon(for state: State) -> some View {
        switch state {
        case .pending:
            Circle().strokeBorder(Color.hairline, lineWidth: 1.5)
        case .active:
            ProgressView().controlSize(.small).scaleEffect(0.6)
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        case .skipped:
            Image(systemName: "minus.circle").foregroundStyle(.tertiary)
        }
    }

    private func color(for state: State) -> Color {
        switch state {
        case .pending, .skipped: .secondary
        case .active: .primary
        case .done: .primary
        case .failed: .red
        }
    }
}

// MARK: - Notices

struct Notice: View {
    let symbol: String
    let tint: Color
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?
    var secondaryTitle: String?
    var secondaryAction: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 15))
                .foregroundStyle(tint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                if let message {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                if let secondaryTitle, let secondaryAction {
                    Button(secondaryTitle, action: secondaryAction)
                }
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.borderedProminent)
                }
            }
            .controlSize(.regular)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(tint.opacity(0.22), lineWidth: 1)
        )
    }
}
