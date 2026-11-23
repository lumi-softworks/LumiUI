import SwiftUI

public struct AppInputField: View {
    @LumiTheme private var theme

    public enum FieldType {
        case plain
        case secure
    }

    /// 输入框密度：`regular` 用于表单，`compact` 用于表格行内的密集编辑。
    public enum Size {
        case regular
        case compact
    }

    let placeholder: Text
    @Binding var text: String
    let fieldType: FieldType
    let size: Size

    public init(
        _ placeholder: LocalizedStringKey,
        text: Binding<String>,
        fieldType: FieldType = .plain,
        size: Size = .regular
    ) {
        self.placeholder = Text(placeholder)
        self._text = text
        self.fieldType = fieldType
        self.size = size
    }

    /// 接受已本地化字符串的占位符（插件用 `pluginLocalization.string(...)` 自行取词时使用）。
    public init(
        localizedPlaceholder: String,
        text: Binding<String>,
        fieldType: FieldType = .plain,
        size: Size = .regular
    ) {
        self.placeholder = Text(verbatim: localizedPlaceholder)
        self._text = text
        self.fieldType = fieldType
        self.size = size
    }

    public var body: some View {
        Group {
            switch fieldType {
            case .plain:
                TextField(text: $text, prompt: placeholder) {
                    EmptyView()
                }
            case .secure:
                SecureField(text: $text, prompt: placeholder) {
                    EmptyView()
                }
            }
        }
        .accessibilityLabel(placeholder)
        .textFieldStyle(.plain)
        .font(font)
        .foregroundColor(theme.textPrimary)
        .padding(contentPadding)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                .fill(theme.appListRowBackground)
                .appInputSurface(cornerRadius: DesignTokens.Radius.sm)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                .stroke(theme.appSubtleBorder, lineWidth: 1)
        )
    }

    private var font: Font {
        switch size {
        case .regular:
            DesignTokens.Typography.body
        case .compact:
            AppTypography.micro
        }
    }

    var contentPadding: EdgeInsets {
        switch size {
        case .regular:
            EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        case .compact:
            EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var text = ""
        var body: some View {
            VStack(spacing: 16) {
                AppInputField("placeholder.plain", text: $text, fieldType: .plain)
                AppInputField("placeholder.secure", text: $text, fieldType: .secure)
                AppInputField(localizedPlaceholder: "紧凑输入", text: $text, size: .compact)
            }
            .padding()
            .frame(width: 300)
            .background(Color.gray.opacity(0.15))
        }
    }
    return PreviewWrapper()
}