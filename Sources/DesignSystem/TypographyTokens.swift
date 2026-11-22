import SwiftUI

// MARK: - 字体系统
extension DesignTokens {
    /// 字体令牌 - 定义应用的排版规范
    ///
    /// 使用系统语义字号，跟随 Dynamic Type 与辅助功能字号缩放；
    /// 基准尺寸保持设计系统原有取值。
    public enum Typography {
        // MARK: - 标题
        public static let largeTitle = Font.system(.largeTitle).weight(.bold)
        public static let title1 = Font.system(.title).weight(.bold)
        public static let title2 = Font.system(.title2).weight(.semibold)
        public static let title3 = Font.system(.title3).weight(.semibold)

        // MARK: - 正文
        public static let body = Font.system(.subheadline)
        public static let bodyEmphasized = Font.system(.subheadline).weight(.medium)
        public static let subheadline = Font.system(.footnote)
        public static let callout = Font.system(.callout).weight(.medium)

        // MARK: - 辅助
        public static let footnote = Font.system(.footnote)
        public static let caption1 = Font.system(.caption)
        public static let caption2 = Font.system(.caption2)

        // MARK: - 代码
        public static let code = Font.system(.footnote, design: .monospaced)
    }
}
