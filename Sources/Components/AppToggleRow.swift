import SwiftUI

public struct AppToggleRow: View {
    @LumiTheme private var theme

    let title: Text
    let systemImage: String?
    let description: Text?
    @Binding var isOn: Bool

    public init(
        title: LocalizedStringKey,
        systemImage: String? = nil,
        description: LocalizedStringKey? = nil,
        isOn: Binding<Bool>
    ) {
        self.title = Text(title)
        self.systemImage = systemImage
        self.description = description.map { Text($0) }
        self._isOn = isOn
    }

    /// 接受已本地化字符串的标题与说明（插件自行取词时使用）。
    public init(
        title: String,
        systemImage: String? = nil,
        description: String? = nil,
        isOn: Binding<Bool>
    ) {
        self.title = Text(verbatim: title)
        self.systemImage = systemImage
        self.description = description.map { Text(verbatim: $0) }
        self._isOn = isOn
    }

    public var body: some View {
        HStack(spacing: AppUI.Spacing.md) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 16))
                    .foregroundColor(theme.primary)
                    .frame(width: 24)
            }

            VStack(alignment: .leading, spacing: 2) {
                title
                    .font(AppUI.Typography.body)
                    .foregroundColor(theme.textPrimary)

                if let description {
                    description
                        .font(AppUI.Typography.caption1)
                        .foregroundColor(theme.textSecondary)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.vertical, AppUI.Spacing.sm)
        .padding(.horizontal, AppUI.Spacing.md)
        .contentShape(Rectangle())
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var toggle1 = true
        @State private var toggle2 = false
        var body: some View {
            VStack(spacing: 0) {
                AppToggleRow(title: LocalizedStringKey(LumiUILocalization.string("Notifications")), systemImage: "bell", isOn: $toggle1)
                AppToggleRow(
                    title: LocalizedStringKey(LumiUILocalization.string("Dark Mode")),
                    description: "Use dark appearance",
                    isOn: $toggle2
                )
            }
            .padding()
            .frame(width: 300)
            .background(Color.gray.opacity(0.15))
        }
    }
    return PreviewWrapper()
}
