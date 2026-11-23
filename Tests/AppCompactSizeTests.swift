import SwiftUI
import Testing
@testable import LumiUI

struct AppCompactSizeTests {
    @Test
    @MainActor
    func inputFieldCompactPaddingIsTighter() {
        let regular = AppInputField(localizedPlaceholder: "Name", text: .constant(""))
        let compact = AppInputField(localizedPlaceholder: "Name", text: .constant(""), size: .compact)

        #expect(regular.size == .regular)
        #expect(compact.size == .compact)
        #expect(regular.contentPadding.top == 8)
        #expect(compact.contentPadding.top == 4)
        #expect(compact.contentPadding.leading == 6)
    }

    @Test
    @MainActor
    func emptyStateCompactMetrics() {
        let regular = AppEmptyState(icon: "tray", title: "Empty")
        let compact = AppEmptyState(icon: "tray", title: "Empty", size: .compact)

        #expect(regular.iconSize == 48)
        #expect(compact.iconSize == 22)
        #expect(regular.spacing == AppUI.Spacing.md)
        #expect(compact.spacing == 8)
        #expect(compact.contentPadding.top == 20)
        #expect(compact.contentPadding.leading == 12)
    }
}