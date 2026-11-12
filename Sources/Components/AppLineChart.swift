import SwiftUI

// MARK: - Point

/// A point in a line chart series.
public struct AppLineChartPoint: Identifiable, Equatable, Sendable {
    public let id: Date
    public let date: Date
    public let value: Double

    public init(date: Date, value: Double) {
        self.id = date
        self.date = date
        self.value = value
    }
}

// MARK: - Point Style

/// How the circles marking individual data points are drawn.
public enum AppLineChartPointStyle: Sendable, Equatable {
    /// Always draw the circles.
    case always
    /// Decide by density: drop the circles when they would overlap.
    case automatic
    /// Draw the line only.
    case never

    /// The smallest gap between two circles that keeps them from touching.
    ///
    /// A circle is 6pt wide, so 7pt of spacing leaves a 1pt gap.
    public static let minimumDotSpacing: CGFloat = 7
}

// MARK: - Guide

/// The visual treatment of a vertical reference line.
public enum AppLineChartGuideStyle: Sendable, Equatable {
    case warning
    case primary
    case secondary
}

/// A vertical reference line anchored to a position in the series.
///
/// The guide sits *between* two data points: `afterPointIndex: 2` draws the
/// line after the third point, which is where a discontinuity caused by
/// that point would appear.
public struct AppLineChartGuide: Identifiable, Equatable, Sendable {
    public let id: String
    /// The index of the point the guide follows; `-1` places it before the first point.
    public let afterPointIndex: Int
    public let style: AppLineChartGuideStyle

    public init(
        id: String,
        afterPointIndex: Int,
        style: AppLineChartGuideStyle = .warning
    ) {
        self.id = id
        self.afterPointIndex = afterPointIndex
        self.style = style
    }
}

// MARK: - Geometry

/// The horizontal arrangement of a line chart.
///
/// Two arrangements are supported:
///
/// - **Fill** — the points are spread evenly across the available width.
///   This is what a chart with a handful of samples looks like.
/// - **Fixed spacing** — every point is exactly `pointSpacing` apart. Once
///   the series is too long to fit, the chart scrolls horizontally instead
///   of compressing the points, so the density on screen never grows.
public struct AppLineChartGeometry: Equatable {
    public let inset: EdgeInsets
    public let viewportWidth: CGFloat
    public let pointSpacing: CGFloat
    public let contentWidth: CGFloat
    public let pointCount: Int

    public init(
        inset: EdgeInsets,
        viewportWidth: CGFloat,
        pointSpacing: CGFloat,
        contentWidth: CGFloat,
        pointCount: Int
    ) {
        self.inset = inset
        self.viewportWidth = viewportWidth
        self.pointSpacing = pointSpacing
        self.contentWidth = contentWidth
        self.pointCount = pointCount
    }

    /// Whether the content is wider than the viewport and therefore scrolls.
    public var isScrollable: Bool { contentWidth > viewportWidth + 0.5 }

    /// Builds a fixed-spacing arrangement.
    ///
    /// The spacing is the larger of `minimumSpacing` and the spacing that
    /// would exactly fill the viewport. A short series therefore still
    /// fills the chart, while a long one keeps the fixed spacing and
    /// starts scrolling.
    public static func fixedSpacing(
        pointCount: Int,
        viewportWidth: CGFloat,
        minimumSpacing: CGFloat,
        inset: EdgeInsets
    ) -> AppLineChartGeometry {
        let plotWidth = max(viewportWidth - inset.leading - inset.trailing, 1)

        guard pointCount > 1 else {
            return AppLineChartGeometry(
                inset: inset,
                viewportWidth: viewportWidth,
                pointSpacing: 0,
                contentWidth: viewportWidth,
                pointCount: pointCount
            )
        }

        let spacing = max(minimumSpacing, plotWidth / CGFloat(pointCount - 1))
        let contentWidth = inset.leading + spacing * CGFloat(pointCount - 1) + inset.trailing

        return AppLineChartGeometry(
            inset: inset,
            viewportWidth: viewportWidth,
            pointSpacing: spacing,
            contentWidth: contentWidth,
            pointCount: pointCount
        )
    }

    /// The horizontal position of a point in content coordinates.
    public func xPosition(forIndex index: Int) -> CGFloat {
        guard pointCount > 1 else {
            return inset.leading + (viewportWidth - inset.leading - inset.trailing) / 2
        }
        return inset.leading + CGFloat(index) * pointSpacing
    }

    /// The index of the point closest to a content coordinate.
    public func index(forContentX x: CGFloat) -> Int? {
        guard pointCount > 0 else { return nil }
        guard pointCount > 1 else { return 0 }
        let index = Int(((x - inset.leading) / pointSpacing).rounded())
        guard index >= 0, index < pointCount else { return nil }
        return index
    }

    /// The horizontal position of a guide, halfway between the point it
    /// follows and the next one.
    public func guideXPosition(afterPointIndex index: Int) -> CGFloat {
        guard index >= 0 else { return inset.leading }
        guard pointCount > 1 else { return inset.leading + (viewportWidth - inset.leading - inset.trailing) / 2 }
        let x = inset.leading + (CGFloat(index) + 0.5) * pointSpacing
        return min(max(x, inset.leading), contentWidth - inset.trailing)
    }

    /// The range of points visible for a given horizontal scroll offset.
    ///
    /// One extra point is included on each side so the line does not visibly
    /// break at the edge of the viewport.
    public func visibleRange(scrollOffset: CGFloat) -> Range<Int> {
        guard pointCount > 0 else { return 0..<0 }
        guard pointCount > 1 else { return 0..<1 }

        let first = (scrollOffset - inset.leading) / pointSpacing
        let last = (scrollOffset + viewportWidth - inset.leading) / pointSpacing
        let lower = max(0, Int(floor(first)) - 1)
        let upper = min(pointCount - 1, Int(ceil(last)) + 1)
        return lower..<max(lower + 1, upper + 1)
    }
}

// MARK: - Chart

/// Reusable line chart for time-series settings data.
public struct AppLineChart: View {
    @LumiTheme private var theme

    public let points: [AppLineChartPoint]
    public let valueLabel: (Double) -> String
    public let accessibilityLabel: String
    /// 最多可见的数据点数；`nil` 表示不限制。
    ///
    /// 超出后按桶取极值降采样，尖峰与断崖不会丢失。
    public let maximumVisiblePoints: Int?
    /// 数据点圆圈的绘制策略。
    public let pointStyle: AppLineChartPointStyle
    /// 固定的数据点间距（点）。
    ///
    /// 设置后曲线按固定间距排布：点数不多时铺满图表，点数变多时保持间距
    /// 并支持横向滚动，屏幕上的点密度不会随着数据增长而变密。
    public let fixedPointSpacing: CGFloat?
    /// 垂直参考线。
    public let guides: [AppLineChartGuide]

    @State private var hoveredIndex: Int?
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollSpaceName: String = UUID().uuidString

    static let inset = EdgeInsets(top: 14, leading: 14, bottom: 24, trailing: 14)

    public init(
        points: [AppLineChartPoint],
        accessibilityLabel: String = "Line chart",
        valueLabel: @escaping (Double) -> String = { String(format: "%.0f", $0) },
        maximumVisiblePoints: Int? = nil,
        pointStyle: AppLineChartPointStyle = .always,
        fixedPointSpacing: CGFloat? = nil,
        guides: [AppLineChartGuide] = []
    ) {
        self.points = points
        self.accessibilityLabel = accessibilityLabel
        self.valueLabel = valueLabel
        self.maximumVisiblePoints = maximumVisiblePoints
        self.pointStyle = pointStyle
        self.fixedPointSpacing = fixedPointSpacing
        self.guides = guides
    }

    public var body: some View {
        GeometryReader { proxy in
            if fixedPointSpacing != nil {
                scrollableBody(viewport: proxy.size)
            } else {
                filledBody(viewport: proxy.size)
            }
        }
        .background(theme.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.primary.opacity(0.12), lineWidth: 1)
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Filled Layout

extension AppLineChart {
    /// Points spread evenly across the available width.
    private func filledBody(viewport: CGSize) -> some View {
        let inset = Self.inset
        let plotWidth = max(viewport.width - inset.leading - inset.trailing, 1)
        let plotHeight = max(viewport.height - inset.top - inset.bottom, 1)

        let layout = AppLineChartDownsampling.layout(
            points: points,
            maximumVisiblePoints: maximumVisiblePoints
        )
        let fractions = layout.xFractions

        // 纵轴始终按原始数据的最大值缩放，降采样不会改变纵轴尺度。
        let maxValue = max(points.map(\.value).max() ?? 0, 1)
        let chartPoints = zip(layout.visiblePoints, fractions).map { point, fraction in
            CGPoint(
                x: inset.leading + plotWidth * CGFloat(fraction),
                y: inset.top + plotHeight * (1 - CGFloat(point.value / maxValue))
            )
        }

        return ZStack(alignment: .topLeading) {
            Canvas { context, size in
                guard !chartPoints.isEmpty, size.width > 0, size.height > 0 else { return }

                var grid = Path()
                for step in 0...2 {
                    let y = inset.top + plotHeight * CGFloat(step) / 2
                    grid.move(to: CGPoint(x: inset.leading, y: y))
                    grid.addLine(to: CGPoint(x: inset.leading + plotWidth, y: y))
                }
                context.stroke(grid, with: .color(theme.divider.opacity(0.7)), lineWidth: 1)

                var line = Path()
                if let first = chartPoints.first {
                    line.move(to: first)
                    for point in chartPoints.dropFirst() {
                        line.addLine(to: point)
                    }
                }
                context.stroke(line, with: .color(theme.primary), lineWidth: 2.2)

                if Self.shouldDrawPoints(style: pointStyle, chartPoints: chartPoints) {
                    for point in chartPoints {
                        context.fill(
                            Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)),
                            with: .color(theme.primary)
                        )
                    }
                }
            }

            guideLayer(layout: layout, plotWidth: plotWidth, plotHeight: plotHeight, inset: inset)

            if let hoveredIndex,
               layout.visiblePoints.indices.contains(hoveredIndex),
               chartPoints.indices.contains(hoveredIndex) {
                let point = chartPoints[hoveredIndex]
                let dataPoint = layout.visiblePoints[hoveredIndex]

                Path { path in
                    path.move(to: CGPoint(x: point.x, y: inset.top))
                    path.addLine(to: CGPoint(x: point.x, y: inset.top + plotHeight))
                }
                .stroke(theme.primary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                Circle()
                    .fill(theme.primary)
                    .frame(width: 9, height: 9)
                    .overlay(Circle().stroke(theme.background, lineWidth: 2))
                    .position(point)

                VStack(alignment: .leading, spacing: 3) {
                    Text(Self.tooltipDateFormatter.string(from: dataPoint.date))
                        .font(.system(size: 10, weight: .medium))
                    Text("X: \(Self.tooltipDateFormatter.string(from: dataPoint.date))")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textSecondary)
                    Text("Y: \(valueLabel(dataPoint.value))")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                }
                .padding(8)
                .foregroundStyle(theme.textPrimary)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(theme.divider, lineWidth: 0.5)
                }
                .shadow(radius: 3, y: 1)
                .fixedSize()
                .position(x: min(max(point.x, 78), max(viewport.width - 78, 78)), y: 38)
            }
        }
        .contentShape(Rectangle())
        .onContinuousHover { phase in
            switch phase {
            case let .active(location):
                guard !fractions.isEmpty else { return }
                let ratio = min(max((location.x - inset.leading) / plotWidth, 0), 1)
                hoveredIndex = Self.nearestVisibleIndex(fractions: fractions, ratio: ratio)
            case .ended:
                hoveredIndex = nil
            }
        }
        .overlay(alignment: .bottomLeading) {
            dateLabel(points.first?.date)
                .padding(.leading, 12)
                .padding(.bottom, 5)
        }
        .overlay(alignment: .bottomTrailing) {
            dateLabel(points.last?.date)
                .padding(.trailing, 12)
                .padding(.bottom, 5)
        }
    }
}

// MARK: - Scrollable Layout

extension AppLineChart {
    /// Points at a fixed spacing, scrolling horizontally once the series
    /// outgrows the viewport.
    private func scrollableBody(viewport: CGSize) -> some View {
        let inset = Self.inset
        let plotHeight = max(viewport.height - inset.top - inset.bottom, 1)

        let geometry = AppLineChartGeometry.fixedSpacing(
            pointCount: points.count,
            viewportWidth: viewport.width,
            minimumSpacing: fixedPointSpacing ?? 8,
            inset: inset
        )

        let visible = geometry.visibleRange(scrollOffset: scrollOffset)
        let visiblePoints = points[visible].enumerated().map { offset, point in
            (index: visible.lowerBound + offset, point: point)
        }

        // 纵轴按原始数据的最大值缩放：滚动到任意位置，纵轴尺度都不变。
        let maxValue = max(points.map(\.value).max() ?? 0, 1)

        return ScrollView(.horizontal) {
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    guard size.width > 0, size.height > 0 else { return }

                    var grid = Path()
                    for step in 0...2 {
                        let y = inset.top + plotHeight * CGFloat(step) / 2
                        grid.move(to: CGPoint(x: inset.leading, y: y))
                        grid.addLine(to: CGPoint(x: geometry.contentWidth - inset.trailing, y: y))
                    }
                    context.stroke(grid, with: .color(theme.divider.opacity(0.7)), lineWidth: 1)

                    guard !visiblePoints.isEmpty else { return }

                    var line = Path()
                    for (offset, entry) in visiblePoints.enumerated() {
                        let x = geometry.xPosition(forIndex: entry.index)
                        let y = inset.top + plotHeight * (1 - CGFloat(entry.point.value / maxValue))
                        if offset == 0 {
                            line.move(to: CGPoint(x: x, y: y))
                        } else {
                            line.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    context.stroke(line, with: .color(theme.primary), lineWidth: 2.2)

                    let chartPoints = visiblePoints.map { entry in
                        CGPoint(
                            x: geometry.xPosition(forIndex: entry.index),
                            y: inset.top + plotHeight * (1 - CGFloat(entry.point.value / maxValue))
                        )
                    }
                    if Self.shouldDrawPoints(style: pointStyle, chartPoints: chartPoints) {
                        for point in chartPoints {
                            context.fill(
                                Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)),
                                with: .color(theme.primary)
                            )
                        }
                    }
                }

                scrollableGuideLayer(geometry: geometry, plotHeight: plotHeight, inset: inset)
            }
            .frame(width: geometry.contentWidth, height: viewport.height)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: AppLineChartScrollOffsetKey.self,
                        value: [scrollSpaceName: -proxy.frame(in: .named(scrollSpaceName)).minX]
                    )
                }
            }
        }
        .coordinateSpace(name: scrollSpaceName)
        .onPreferenceChange(AppLineChartScrollOffsetKey.self) { offsets in
            let offset = offsets[scrollSpaceName] ?? 0
            guard abs(offset - scrollOffset) > 0.5 else { return }
            scrollOffset = offset
        }
        .onContinuousHover { phase in
            switch phase {
            case let .active(location):
                guard !points.isEmpty else { return }
                let contentX = location.x + scrollOffset
                hoveredIndex = geometry.index(forContentX: contentX)
            case .ended:
                hoveredIndex = nil
            }
        }
        .overlay {
            if let hoveredIndex,
               points.indices.contains(hoveredIndex) {
                let viewportX = geometry.xPosition(forIndex: hoveredIndex) - scrollOffset
                let dataPoint = points[hoveredIndex]

                Path { path in
                    path.move(to: CGPoint(x: viewportX, y: inset.top))
                    path.addLine(to: CGPoint(x: viewportX, y: inset.top + plotHeight))
                }
                .stroke(theme.primary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                Circle()
                    .fill(theme.primary)
                    .frame(width: 9, height: 9)
                    .overlay(Circle().stroke(theme.background, lineWidth: 2))
                    .position(x: viewportX, y: inset.top + plotHeight * (1 - CGFloat(dataPoint.value / maxValue)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(Self.tooltipDateFormatter.string(from: dataPoint.date))
                        .font(.system(size: 10, weight: .medium))
                    Text("X: \(Self.tooltipDateFormatter.string(from: dataPoint.date))")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.textSecondary)
                    Text("Y: \(valueLabel(dataPoint.value))")
                        .font(.system(size: 11, weight: .semibold))
                        .monospacedDigit()
                }
                .padding(8)
                .foregroundStyle(theme.textPrimary)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(theme.divider, lineWidth: 0.5)
                }
                .shadow(radius: 3, y: 1)
                .fixedSize()
                .position(
                    x: min(max(viewportX, 78), max(viewport.width - 78, 78)),
                    y: 38
                )
            }
        }
        .overlay(alignment: .bottomLeading) {
            dateLabel(visiblePoints.first?.point.date)
                .padding(.leading, 12)
                .padding(.bottom, 5)
        }
        .overlay(alignment: .bottomTrailing) {
            dateLabel(visiblePoints.last?.point.date)
                .padding(.trailing, 12)
                .padding(.bottom, 5)
        }
    }
}

// MARK: - Guides

extension AppLineChart {
    /// Guides for the fill layout, positioned between two points.
    private func guideLayer(
        layout: AppLineChartLayout,
        plotWidth: CGFloat,
        plotHeight: CGFloat,
        inset: EdgeInsets
    ) -> some View {
        ForEach(guides) { guide in
            let index = min(max(guide.afterPointIndex, -1), max(layout.originalCount - 1, -1))
            let ratio: CGFloat = layout.originalCount > 1
                ? (CGFloat(index) + 0.5) / CGFloat(layout.originalCount - 1)
                : 0.5
            let x = inset.leading + plotWidth * min(max(ratio, 0), 1)

            Path { path in
                path.move(to: CGPoint(x: x, y: inset.top))
                path.addLine(to: CGPoint(x: x, y: inset.top + plotHeight))
            }
            .stroke(
                color(for: guide.style).opacity(0.75),
                style: StrokeStyle(lineWidth: 1, dash: [3, 3])
            )
        }
    }

    /// Guides for the scrollable layout, positioned between two points.
    private func scrollableGuideLayer(
        geometry: AppLineChartGeometry,
        plotHeight: CGFloat,
        inset: EdgeInsets
    ) -> some View {
        ForEach(guides) { guide in
            let x = geometry.guideXPosition(afterPointIndex: guide.afterPointIndex)

            Path { path in
                path.move(to: CGPoint(x: x, y: inset.top))
                path.addLine(to: CGPoint(x: x, y: inset.top + plotHeight))
            }
            .stroke(
                color(for: guide.style).opacity(0.75),
                style: StrokeStyle(lineWidth: 1, dash: [3, 3])
            )
        }
    }

    private func color(for style: AppLineChartGuideStyle) -> Color {
        switch style {
        case .warning: return theme.warning
        case .primary: return theme.primary
        case .secondary: return theme.textSecondary
        }
    }
}

// MARK: - Helpers

extension AppLineChart {
    /// 是否绘制数据点圆圈。
    ///
    /// `.automatic` 下按相邻点的最小水平间距判断：间距不足时圆点会互相重叠，
    /// 叠成一条锯齿状的粗带，此时只保留折线。
    static func shouldDrawPoints(
        style: AppLineChartPointStyle,
        chartPoints: [CGPoint]
    ) -> Bool {
        switch style {
        case .always:
            return true
        case .never:
            return false
        case .automatic:
            guard chartPoints.count > 1 else { return true }
            var minimumSpacing = CGFloat.greatestFiniteMagnitude
            for pair in zip(chartPoints, chartPoints.dropFirst()) {
                minimumSpacing = min(minimumSpacing, abs(pair.1.x - pair.0.x))
            }
            return minimumSpacing >= AppLineChartPointStyle.minimumDotSpacing
        }
    }

    /// 找到与给定水平比例最接近的可见点下标。
    private static func nearestVisibleIndex(fractions: [Double], ratio: CGFloat) -> Int {
        var bestIndex = 0
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for (index, fraction) in fractions.enumerated() {
            let distance = abs(CGFloat(fraction) - ratio)
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        return bestIndex
    }

    private func dateLabel(_ date: Date?) -> some View {
        Text(date.map(Self.axisDateFormatter.string(from:)) ?? "")
            .font(.system(size: 9))
            .foregroundStyle(theme.textTertiary)
            .monospacedDigit()
    }

    private static let axisDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter
    }()

    private static let tooltipDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - Scroll Offset

/// Reports the horizontal scroll offset of every scrollable chart.
///
/// The offsets are keyed by coordinate space name so that several charts on
/// the same screen do not read each other's scroll position.
private struct AppLineChartScrollOffsetKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] { [:] }

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}
