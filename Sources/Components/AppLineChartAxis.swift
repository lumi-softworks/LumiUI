import Foundation

// MARK: - Axis Label

/// How the horizontal axis labels are produced.
///
/// The horizontal axis of a line chart does not always represent time: a
/// chart of one value per request is laid out by request index, while a
/// chart of one value per day is laid out by date. The axis has to say
/// which one it is, otherwise the labels contradict the layout.
public enum AppLineChartAxisStyle: Sendable {
    /// Labels show the date of the point (`M/d`).
    ///
    /// The right choice when the horizontal axis really is a time axis.
    case date
    /// Labels show the position of the point in the series (`#12`).
    ///
    /// The right choice when the horizontal axis is an index, for example
    /// one request after another.
    case index
    /// Labels are supplied by the caller.
    case custom(@Sendable (Int) -> String)

    /// The label for the point at `index`.
    public func label(index: Int, date: Date) -> String {
        switch self {
        case .date:
            return Self.dateFormatter.string(from: date)
        case .index:
            return "#\(index + 1)"
        case let .custom(format):
            return format(index)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter
    }()
}

// MARK: - Tick

/// A tick mark on the horizontal axis.
public struct AppLineChartTick: Equatable, Sendable {
    /// The index of the point the tick is anchored to.
    public let pointIndex: Int
    /// The label drawn under the tick.
    public let text: String

    public init(pointIndex: Int, text: String) {
        self.pointIndex = pointIndex
        self.text = text
    }
}

// MARK: - Tick Layout

/// Computes the ticks shown along the horizontal axis.
///
/// Ticks are placed on evenly spaced points of the series so that they stay
/// legible however long the series is, and never overlap each other.
public enum AppLineChartTickLayout {

    /// How many ticks to aim for.
    public static let preferredTickCount = 4

    /// The ticks for a series.
    ///
    /// - Parameters:
    ///   - points: The full series, used to read the dates of the labels.
    ///   - visibleRange: The range of points currently visible.
    ///   - axisStyle: How the labels are produced.
    ///   - preferredCount: How many ticks to aim for.
    /// - Returns: The ticks to draw, ordered by position.
    public static func ticks(
        points: [AppLineChartPoint],
        visibleRange: Range<Int>,
        axisStyle: AppLineChartAxisStyle,
        preferredCount: Int = preferredTickCount
    ) -> [AppLineChartTick] {
        guard !points.isEmpty, preferredCount > 0 else { return [] }

        // 只在可见范围内取刻度；不可见的点画出来也没有意义。
        let lower = max(visibleRange.lowerBound, 0)
        let upper = min(visibleRange.upperBound, points.count)
        guard upper > lower else { return [] }

        let visibleCount = upper - lower
        let count = min(preferredCount, visibleCount)
        guard count > 0 else { return [] }

        // 单点可见时只标这一个点。
        guard count > 1 else {
            return [tick(at: lower, points: points, axisStyle: axisStyle)]
        }

        var result: [AppLineChartTick] = []
        var previousIndex: Int?

        for slot in 0..<count {
            let position = lower + (visibleCount - 1) * slot / (count - 1)
            // 相邻刻度可能落在同一个点上（可见点很少时），跳过重复项。
            if let previousIndex, previousIndex == position { continue }
            previousIndex = position

            result.append(tick(at: position, points: points, axisStyle: axisStyle))
        }

        return result
    }

    private static func tick(
        at index: Int,
        points: [AppLineChartPoint],
        axisStyle: AppLineChartAxisStyle
    ) -> AppLineChartTick {
        let date = points.indices.contains(index) ? points[index].date : Date.distantPast
        return AppLineChartTick(
            pointIndex: index,
            text: axisStyle.label(index: index, date: date)
        )
    }
}
