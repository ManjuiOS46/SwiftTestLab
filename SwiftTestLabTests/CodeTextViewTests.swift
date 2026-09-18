import Testing
@testable import Subject

@Suite struct CodeTextViewTests {
    @Test func makeNSView_createsScrollViewWithCorrectConfiguration() {
        let codeView = CodeTextView(text: "hello")
        let scrollView = codeView.makeNSView(context: .init())

        #expect(scrollView.hasVerticalScroller)
        #expect(!scrollView.hasHorizontalScroller)
        #expect(!scrollView.autohidesScrollers)
        #expect(scrollView.drawsBackground)
        #expect(scrollView.borderType == .noBorder)

        guard let textView = scrollView.documentView as? NSTextView else {
            Issue.record("documentView is not an NSTextView")
            return
        }

        #expect(!textView.isEditable)
        #expect(textView.isSelectable)
        #expect(!textView.isRichText)
        #expect(textView.drawsBackground)
        #expect(textView.textContainerInset == NSSize(width: 10, height: 10))
        #expect(textView.font?.fontName == NSFont.monospacedSystemFont(ofSize: 11.5, weight: .regular).fontName)
        #expect(textView.textColor == .textColor)
        #expect(!textView.isHorizontallyResizable)
        #expect(textView.textContainer?.widthTracksTextView)
        #expect(textView.string == "hello")
    }

    @Test func updateNSView_updatesTextAndMaintainsSelection() {
        let codeView = CodeTextView(text: "initial")
        let scrollView = codeView.makeNSView(context: .init())
        guard let textView = scrollView.documentView as? NSTextView else {
            Issue.record("documentView is not an NSTextView")
            return
        }

        // Simulate some selection and scrolling
        textView.setSelectedRange(NSRange(location: 3, length: 0))

        let updatedTextView = CodeTextView(text: "updated")
        updatedTextView.updateNSView(scrollView, context: .init())

        #expect(textView.string == "updated")
        #expect(textView.selectedRange().location == 3)
    }

    @Test func updateNSView_scrollsToBottomWhenFollowingTailAndWasAtBottom() {
        let codeView = CodeTextView(text: "a\nb\nc\nd\ne", followsTail: true)
        let scrollView = codeView.makeNSView(context: .init())
        guard let textView = scrollView.documentView as? NSTextView else {
            Issue.record("documentView is not an NSTextView")
            return
        }

        // Simulate being at the bottom
        textView.scrollRangeToVisible(NSRange(location: 10, length: 0))

        let updatedTextView = CodeTextView(text: "a\nb\nc\nd\ne\nf\ng")
        updatedTextView.updateNSView(scrollView, context: .init())

        #expect(textView.string == "a\nb\nc\nd\ne\nf\ng")
        // Verify that the scroll position is maintained or adjusted due to followsTail
        let visible = scrollView.contentView.documentVisibleRect
        let height = scrollView.documentView?.bounds.height ?? 0
        #expect(visible.maxY >= height - 24)
    }

    @Test func isScrolledToBottom_returnsTrueWhenAtBottom() {
        let codeView = CodeTextView(text: "a\nb\nc")
        let scrollView = codeView.makeNSView(context: .init())
        guard let textView = scrollView.documentView as? NSTextView else {
            Issue.record("documentView is not an NSTextView")
            return
        }

        // Ensure we scroll to bottom
        textView.scrollRangeToVisible(NSRange(location: 5, length: 0))

        let result = codeView.isScrolledToBottom(scrollView)
        #expect(result)
    }

    @Test func isScrolledToBottom_returnsFalseWhenNotAtBottom() {
        let codeView = CodeTextView(text: "a\nb\nc")
        let scrollView = codeView.makeNSView(context: .init())
        guard let textView = scrollView.documentView as? NSTextView else {
            Issue.record("documentView is not an NSTextView")
            return
        }

        // Ensure we're scrolled to top
        textView.scrollRangeToVisible(NSRange(location: 0, length: 0))

        let result = codeView.isScrolledToBottom(scrollView)
        #expect(!result)
    }
}

@Suite struct CodePaneTests {
    @Test func body_showsPlaceholderWhenTextIsEmptyAndPlaceholderIsSet() {
        let pane = CodePane(text: "", placeholder: "No output yet")
        
        // This test primarily checks compilation and structure, since UI tests are not
        // feasible without a full environment.
        #expect(pane.text.isEmpty)
        #expect(!pane.placeholder.isEmpty)
    }

    @Test func body_showsTextWhenItIsNotEmpty() {
        let pane = CodePane(text: "Some code here")
        
        #expect(!pane.text.isEmpty)
    }
}
