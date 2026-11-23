import SwiftUI

public struct AppEmptyState: View {
    @LumiMotionPreferenceReader private var motionPreference
    @LumiTheme private var theme

    let icon: String
    let title: Text
    let description: Text?
    let actionTitle: Text?
    let action: (() -> Void)?
    let size: Size

    /// 空态密度：`regular` 用于内容区，`compact` 用于窄侧栏。
    public enum Size {
        case regular
        case compact
    }

    @State private var isHovering = false

    public init(
        icon: String,
        title: LocalizedStringKey,
        description: LocalizedStringKey? = nil,
        size: Size = .regular
    ) {
        self.icon = icon
        self.title = Text(title)
        self.description = description.map { Text($0) }
        self.actionTitle = nil
        self.action = nil
        self.size = size
    }

    public init(
        icon: String,
        title: String,
        description: String? = nil,
        size: Size = .regular
    ) {
        self.icon = icon
        self.title = Text(title)
        self.description = description.map(Text.init)
        self.actionTitle = nil
        self.action = nil
        self.size = size
    }

    public init(
        icon: String,
        title: LocalizedStringKey,
        description: LocalizedStringKey? = nil,
        actionTitle: LocalizedStringKey,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = Text(title)
        self.description = description.map { Text($0) }
        self.actionTitle = Text(actionTitle)
        self.action = action
        self.size = .regular
    }

    public init(
        icon: String,
        title: String,
        description: String? = nil,
        actionTitle: String,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = Text(title)
        self.description = description.map(Text.init)
        self.actionTitle = Text(actionTitle)
        self.action = action
        self.size = .regular
    }

    public var body: some View {
        VStack(spacing: spacing) {
            Image(systemName: icon)
                .font(.system(size: iconSize))
                .foregroundColor(iconColor)
                .scaleEffect(isHovering && showsHoverAnimation && motionPreference.allowsMotion ? AppUI.Motion.hoverScale : 1.0)
                .animation(AppUI.Motion.enabled(AppUI.Motion.hover, preference: motionPreference), value: isHovering)
                .onHover { hovering in
                    guard showsHoverAnimation else { return }
                    AppUI.Motion.animate(AppUI.Motion.enabled(AppUI.Motion.hover, preference: motionPreference)) {
                        isHovering = hovering
                    }
                }

            title
                .font(titleFont)
                .foregroundColor(titleColor)

            if let description {
                description
                    .font(descriptionFont)
                    .foregroundColor(descriptionColor)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: descriptionMaxWidth)
            }

            if let actionTitle, let action {
                AppButton(actionTitle, style: .secondary, size: .small, action: action)
                    .padding(.top, AppUI.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: size == .regular ? CGFloat.infinity : nil)
        .padding(contentPadding)
    }

    var spacing: CGFloat {
        size == .regular ? AppUI.Spacing.md : 8
    }

    var iconSize: CGFloat {
        size == .regular ? 48 : 22
    }

    private var iconColor: Color {
        switch size {
        case .regular:
            theme.textSecondary.opacity(0.6)
        case .compact:
            theme.textTertiary
        }
    }

    private var titleFont: Font {
        size == .regular ? AppUI.Typography.bodyEmphasized : AppTypography.micro
    }

    private var titleColor: Color {
        size == .regular ? theme.textSecondary : theme.textTertiary
    }

    private var descriptionFont: Font {
        size == .regular ? AppUI.Typography.caption1 : AppTypography.caption
    }

    private var descriptionColor: Color {
        theme.textTertiary
    }

    private var descriptionMaxWidth: CGFloat? {
        size == .compact ? 220 : nil
    }

    var contentPadding: EdgeInsets {
        switch size {
        case .regular:
            EdgeInsets(top: AppUI.Spacing.xl, leading: AppUI.Spacing.xl, bottom: AppUI.Spacing.xl, trailing: AppUI.Spacing.xl)
        case .compact:
            EdgeInsets(top: 20, leading: 12, bottom: 20, trailing: 12)
        }
    }

    private var showsHoverAnimation: Bool {
        size == .regular
    }
}

#Preview {
    VStack(spacing: 16) {
        AppEmptyState(
            icon: "doc.text.magnifyingglass",
            title: LumiUILocalization.string("No Results"),
            description: "Try adjusting your search terms"
        )
        .frame(height: 200)
    }
    .frame(width: 300)
    .background(Color.gray.opacity(0.15))
}

#Preview("With Action") {
    AppEmptyState(
        icon: "tray",
        title: LumiUILocalization.string("Nothing Here Yet"),
        description: "Create your first item to get started",
        actionTitle: "Get Started",
        action: {}
    )
    .frame(width: 300, height: 250)
    .background(Color.gray.opacity(0.15))
}
