import SwiftUI

/// Public typography tokens for app and plugin UI.
///
/// Tokens follow system text styles so Dynamic Type and accessibility sizes
/// scale content while keeping the design system's base sizes.
public enum AppTypography {
    public static let largeTitle = Font.system(.largeTitle).weight(.bold)
    public static let title = Font.system(.title2).weight(.semibold)
    public static let sectionTitle = Font.system(.subheadline).weight(.semibold)
    public static let body = Font.system(.subheadline)
    public static let bodyEmphasized = Font.system(.subheadline).weight(.medium)
    public static let callout = Font.system(.footnote).weight(.medium)
    public static let caption = Font.system(.caption)
    public static let captionEmphasized = Font.system(.caption).weight(.medium)
    public static let micro = Font.system(.caption2)
    public static let microEmphasized = Font.system(.caption2).weight(.medium)
    public static let monoCaption = Font.system(.caption, design: .monospaced)
    public static let monoMicro = Font.system(.caption2, design: .monospaced)
}

public extension Font {
    static var appLargeTitle: Font { AppTypography.largeTitle }
    static var appTitle: Font { AppTypography.title }
    static var appSectionTitle: Font { AppTypography.sectionTitle }
    static var appBody: Font { AppTypography.body }
    static var appBodyEmphasized: Font { AppTypography.bodyEmphasized }
    static var appCallout: Font { AppTypography.callout }
    static var appCaption: Font { AppTypography.caption }
    static var appCaptionEmphasized: Font { AppTypography.captionEmphasized }
    static var appMicro: Font { AppTypography.micro }
    static var appMicroEmphasized: Font { AppTypography.microEmphasized }
    static var appMonoCaption: Font { AppTypography.monoCaption }
    static var appMonoMicro: Font { AppTypography.monoMicro }
}
