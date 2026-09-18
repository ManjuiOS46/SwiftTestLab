//
//  CodeTextView.swift
//  SwiftTestLab
//
//  Created by Swamy Manju Ramakrishna on 18/09/2026.
//

import AppKit
import SwiftUI

/// A read-only code pane backed by NSTextView.
///
/// SwiftUI's ScrollView reports its whole content as its ideal size, which made
/// windows grow past the screen, and a two-axis ScrollView around wide monospaced
/// text would not reliably scroll to either end. AppKit's scroll view has none of
/// those problems, handles long logs without redrawing everything, and gives real
/// text selection and Find for free.
struct CodeTextView: NSViewRepresentable {
    let text: String
    var followsTail = false

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .textBackgroundColor
        scrollView.borderType = .noBorder

        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        textView.isEditable = false
        textView.isSelectable = true
        textView.isRichText = false
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.font = NSFont.monospacedSystemFont(ofSize: 11.5, weight: .regular)
        textView.textColor = .textColor
        // Wrapped, so a long compiler line is readable rather than off to the right.
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.string = text
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        guard textView.string != text else { return }

        // Leave the reader where they are unless this pane is following a live log
        // and they haven't scrolled away from the end themselves.
        let wasAtBottom = isScrolledToBottom(scrollView)
        let selected = textView.selectedRange()

        textView.string = text
        textView.setSelectedRange(NSRange(location: min(selected.location, text.utf16.count), length: 0))

        if followsTail && wasAtBottom {
            textView.scrollRangeToVisible(NSRange(location: text.utf16.count, length: 0))
        }
    }

    private func isScrolledToBottom(_ scrollView: NSScrollView) -> Bool {
        let visible = scrollView.contentView.documentVisibleRect
        let height = scrollView.documentView?.bounds.height ?? 0
        return visible.maxY >= height - 24
    }
}

/// The framed pane the rest of the UI uses.
struct CodePane: View {
    let text: String
    var followsTail = false
    var placeholder = ""

    var body: some View {
        ZStack(alignment: .topLeading) {
            CodeTextView(text: text, followsTail: followsTail)
            if text.isEmpty && !placeholder.isEmpty {
                Text(placeholder)
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .padding(14)
                    .allowsHitTesting(false)
            }
        }
        .frame(minHeight: 200, idealHeight: 320, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.hairline, lineWidth: 1)
        )
    }
}
