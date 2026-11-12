import Foundation

// MARK: - Layout

/// 折线图可见点的布局结果。
///
/// 降采样后依然携带每个可见点在**原始数组**中的下标：横坐标始终按原始下标
/// 计算，因此调用方（压缩标记等覆盖层）可以独立定位，不会因为降采样而错位。
public struct AppLineChartLayout: Equatable, Sendable {
    /// 参与绘制的点，保持原始顺序。
    public let visiblePoints: [AppLineChartPoint]
    /// 每个可见点在原始数组中的下标。
    public let visibleIndices: [Int]
    /// 原始点数。
    public let originalCount: Int

    public init(visiblePoints: [AppLineChartPoint], visibleIndices: [Int], originalCount: Int) {
        self.visiblePoints = visiblePoints
        self.visibleIndices = visibleIndices
        self.originalCount = originalCount
    }

    /// 是否发生了降采样。
    public var isDecimated: Bool { visiblePoints.count < originalCount }

    /// 每个可见点的水平位置比例（0...1），按原始下标计算。
    ///
    /// 单点时落在 0.5，与图表内部对单点的处理一致。
    public var xFractions: [Double] {
        guard !visibleIndices.isEmpty else { return [] }
        guard originalCount > 1 else { return visibleIndices.map { _ in 0.5 } }
        return visibleIndices.map { Double($0) / Double(originalCount - 1) }
    }
}

// MARK: - Downsampling

/// 折线图降采样。
///
/// 降采样分两级，目的是**不丢关键信息**：
///
/// 1. 先挑出必须保留的点：首尾，以及所有严格高于（或低于）左右邻居的局部极值点
///    —— 尖峰与断崖正是曲线上最该看见的信息。
/// 2. 关键点仍超出上限时（数据本身锯齿过密），再按桶取每桶的极值。
///
/// 横坐标比例始终基于原始下标，降采样不会让覆盖层错位。
public enum AppLineChartDownsampling {

    /// 计算可见点布局。
    ///
    /// - Parameters:
    ///   - points: 原始点数组。
    ///   - maximumVisiblePoints: 最多可见点数；`nil` 或小于 2 时不降采样。
    /// - Returns: 可见点布局，横坐标比例基于原始下标。
    public static func layout(
        points: [AppLineChartPoint],
        maximumVisiblePoints: Int?
    ) -> AppLineChartLayout {
        let originalCount = points.count

        guard let limit = maximumVisiblePoints, limit >= 2, originalCount > limit else {
            return AppLineChartLayout(
                visiblePoints: points,
                visibleIndices: Array(0..<originalCount),
                originalCount: originalCount
            )
        }

        let critical = criticalIndices(points: points)

        if critical.count <= limit {
            let indices = select(critical: critical, originalCount: originalCount, limit: limit)
            return AppLineChartLayout(
                visiblePoints: indices.map { points[$0] },
                visibleIndices: indices,
                originalCount: originalCount
            )
        }

        let indices = bucketedIndices(points: points, limit: limit)
        return AppLineChartLayout(
            visiblePoints: indices.map { points[$0] },
            visibleIndices: indices,
            originalCount: originalCount
        )
    }

    // MARK: - Critical Points

    /// 必须保留的点：首尾 + 所有严格局部极值点。
    private static func criticalIndices(points: [AppLineChartPoint]) -> Set<Int> {
        var result: Set<Int> = [0, points.count - 1]

        guard points.count >= 3 else { return result }

        for index in 1..<(points.count - 1) {
            let value = points[index].value
            let previous = points[index - 1].value
            let next = points[index + 1].value
            if (value > previous && value > next) || (value < previous && value < next) {
                result.insert(index)
            }
        }

        return result
    }

    /// 在关键点之外，用剩余名额均匀补点，保持曲线形状。
    private static func select(
        critical: Set<Int>,
        originalCount: Int,
        limit: Int
    ) -> [Int] {
        var selected = critical
        let remaining = limit - selected.count
        guard remaining > 0 else { return selected.sorted() }

        let optional = (0..<originalCount).filter { !critical.contains($0) }
        guard !optional.isEmpty else { return selected.sorted() }

        // 均匀取样：名额多于候选点时按比例压缩，避免重复插入同一点。
        let slots = min(remaining, optional.count)
        for slot in 0..<slots {
            let position = slot * optional.count / slots
            selected.insert(optional[position])
        }

        return selected.sorted()
    }

    // MARK: - Bucketed Fallback

    /// 关键点过多时的兜底：按桶取每桶的极值。
    ///
    /// 每桶最多产出 2 个点，首尾各 1 个；结果去重后严格不超过上限。
    private static func bucketedIndices(points: [AppLineChartPoint], limit: Int) -> [Int] {
        let originalCount = points.count
        // 上限很小（2 或 3）时首尾已占满或几乎占满，不再分桶。
        guard limit > 2 else { return limit >= 2 ? [0, originalCount - 1] : [0] }

        let interiorCount = originalCount - 2
        // 每个桶 2 个名额（极小 + 极大），首尾各留 1 个。
        let bucketCount = max(min((limit - 2) / 2, interiorCount), 1)

        var selected: Set<Int> = [0, originalCount - 1]
        for bucket in 0..<bucketCount {
            let start = 1 + (interiorCount * bucket) / bucketCount
            let end = 1 + (interiorCount * (bucket + 1)) / bucketCount
            guard end > start else { continue }

            var minIndex = start
            var maxIndex = start
            for index in start..<end {
                if points[index].value < points[minIndex].value { minIndex = index }
                if points[index].value > points[maxIndex].value { maxIndex = index }
            }

            if minIndex == maxIndex {
                // 桶内取值全同，取中点让平坦区段也均匀分布。
                selected.insert((start + end) / 2)
            } else {
                selected.insert(minIndex)
                selected.insert(maxIndex)
            }
        }

        // 去重后仍可能超限（多桶命中同一点），按均匀间隔裁剪到上限。
        let ordered = selected.sorted()
        guard ordered.count > limit else { return ordered }

        // 首尾是曲线的起止锚点，裁剪时必须保留；中间名额再均匀分配。
        var trimmed: [Int] = [ordered.first ?? 0]
        let middleSlots = limit - 2
        let interior = Array(ordered.dropFirst().dropLast())
        if middleSlots > 0, !interior.isEmpty {
            for slot in 0..<middleSlots {
                let position = slot * interior.count / middleSlots
                trimmed.append(interior[position])
            }
        }
        if limit >= 2 {
            trimmed.append(ordered.last ?? 0)
        }
        return Array(Set(trimmed)).sorted()
    }
}
