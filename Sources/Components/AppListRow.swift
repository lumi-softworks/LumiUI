import SwiftUI

public struct AppListRow<Content: View>: View {
    @LumiTheme private var theme
    @LumiMotionPreferenceReader private var motionPreference

    let isSelected: Bool
    /// 语义色调：用于「被阻止 / 允许」这类状态行。
    ///
    /// 设置后行底色带该色调的淡染，悬停时加深；`isSelected` 仍优先。
    let accent: Color?
    let action: (() -> Void)?
    let content: Content

    @State private var isHovered = false

    public init(
        isSelected: Bool = false,
        accent: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.isSelected = isSelected
        self.accent = accent
        self.action = nil
        self.content = content()
    }

    public init(
        isSelected: Bool = false,
        accent: Color? = nil,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.isSelected = isSelected
        self.accent = accent
        self.action = action
        self.content = content()
    }

    public var body: some View {
        Group {
            if let action {
                Button(action: action) { rowSurface }
                    .buttonStyle(.plain)
            } else {
                // 无动作时不套 Button：行内可能含自己的控件（如开关、按钮），
                // 外层 Button 会吞掉这些控件的点击。
                rowSurface
            }
        }
        .contentShape(Rectangle())
    }

    private var rowSurface: some View {
        content
            .padding(.horizontal, AppUI.Spacing.md)
            .padding(.vertical, AppUI.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(rowBackground)
            .overlay(rowBorder)
            .scaleEffect(isHovered && motionPreference.allowsMotion ? AppUI.Motion.rowHoverScale : 1.0)
            .shadow(color: Color.black.opacity(isHovered ? 0.06 : 0), radius: isHovered ? 8 : 0, y: isHovered ? 3 : 0)
            .contentShape(Rectangle())
            .onHover { hovering in
                AppUI.Motion.animate(AppUI.Motion.enabled(AppUI.Motion.hover, preference: motionPreference)) {
                    isHovered = hovering
                }
            }
    }

    @ViewBuilder
    private var rowBackground: some View {
        Group {
            if isSelected {
                theme.appListRowSelectedBackground
            } else if let accent {
                accent.opacity(isHovered ? 0.18 : 0.10)
            } else if isHovered {
                theme.appListRowHoverBackground
            } else {
                theme.appListRowBackground
            }
        }
    }

    @ViewBuilder
    private var rowBorder: some View {
        if isSelected {
            Rectangle()
                .stroke(theme.primary.opacity(0.3), lineWidth: 1)
        } else if let accent {
            Rectangle()
                .stroke(accent.opacity(isHovered ? 0.55 : 0.3), lineWidth: 1)
        } else if isHovered {
            Rectangle()
                .stroke(theme.appHoverBorder, lineWidth: 1)
        }
    }
}

#Preview {
    VStack(spacing: 4) {
        AppListRow(isSelected: true) {
            Text(LumiUILocalization.string("Selected Item"))
        }
        AppListRow {
            Text(LumiUILocalization.string("Normal Item"))
        }
        AppListRow(isSelected: false, action: {}) {
            HStack {
                Image(systemName: "star")
                Text(LumiUILocalization.string("With Action"))
            }
        }
    }
    .frame(width: 300)
    .padding()
    .background(Color.gray.opacity(0.15))
}
