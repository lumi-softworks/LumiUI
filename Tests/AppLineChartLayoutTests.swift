import Foundation
import Testing

@testable import LumiUI

/// `AppLineChart` 降采样与点样式策略的回归测试。
///
/// 覆盖两件事：
/// 1. 降采样后可见点数受限，且每桶的极值不会被丢掉；
/// 2. 横坐标比例始终按**原始下标**计算，调用方（压缩标记等覆盖层）可独立定位。
struct AppLineChartLayoutTests {

    // MARK: - Helpers

    private func points(_ values: [Double]) -> [AppLineChartPoint] {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        return values.enumerated().map { index, value in
            AppLineChartPoint(
                date: base.addingTimeInterval(Double(index) * 60),
                value: value
            )
        }
    }

    // MARK: - 不降采样

    @Test("未指定上限时不降采样")
    func noLimitKeepsAllPoints() {
        let source = points((0..<50).map { Double($0) })

        let layout = AppLineChartDownsampling.layout(points: source, maximumVisiblePoints: nil)

        #expect(layout.visiblePoints.count == 50)
        #expect(layout.visibleIndices == Array(0..<50))
        #expect(layout.isDecimated == false)
    }

    @Test("点数未超过上限时不降采样")
    func underLimitKeepsAllPoints() {
        let source = points([1, 2, 3, 4, 5])

        let layout = AppLineChartDownsampling.layout(points: source, maximumVisiblePoints: 10)

        #expect(layout.visiblePoints.count == 5)
        #expect(layout.isDecimated == false)
    }

    @Test("上限小于 2 时不降采样")
    func invalidLimitKeepsAllPoints() {
        let source = points([1, 2, 3, 4, 5])

        let layout = AppLineChartDownsampling.layout(points: source, maximumVisiblePoints: 1)

        #expect(layout.visiblePoints.count == 5)
        #expect(layout.isDecimated == false)
    }

    // MARK: - 降采样

    @Test("降采样后可见点数不超过上限")
    func decimationRespectsLimit() {
        let source = points((0..<500).map { Double($0 % 37) })

        let layout = AppLineChartDownsampling.layout(points: source, maximumVisiblePoints: 40)

        #expect(layout.visiblePoints.count <= 40)
        #expect(layout.isDecimated)
    }

    @Test("降采样保留首尾点")
    func decimationKeepsEndpoints() {
        let source = points((0..<300).map { Double($0) })

        let layout = AppLineChartDownsampling.layout(points: source, maximumVisiblePoints: 30)

        #expect(layout.visibleIndices.first == 0)
        #expect(layout.visibleIndices.last == 299)
    }

    @Test("降采样保留每桶的极大值")
    func decimationKeepsPeaks() {
        // 每 10 个点放一个尖峰，其余为低值。
        var values = (0..<300).map { _ in 1.0 }
        for index in stride(from: 0, to: 300, by: 10) {
            values[index] = 100.0
        }
        let source = points(values)

        let layout = AppLineChartDownsampling.layout(points: source, maximumVisiblePoints: 50)

        let keptValues = layout.visiblePoints.map(\.value)
        let peakCount = values.filter { $0 == 100.0 }.count
        let keptPeaks = keptValues.filter { $0 == 100.0 }.count

        // 尖峰是曲线的关键信息，一个都不能因为降采样而消失。
        #expect(keptPeaks == peakCount, "尖峰丢失：\(peakCount) → \(keptPeaks)")
    }

    @Test("降采样保留每桶的极小值")
    func decimationKeepsDips() {
        // 每 10 个点放一个深谷，其余为高值。
        var values = (0..<300).map { _ in 50.0 }
        for index in stride(from: 0, to: 300, by: 10) {
            values[index] = 0.5
        }
        let source = points(values)

        let layout = AppLineChartDownsampling.layout(points: source, maximumVisiblePoints: 50)

        let keptDips = layout.visiblePoints.map(\.value).filter { $0 == 0.5 }.count
        let expectedDips = values.filter { $0 == 0.5 }.count

        #expect(keptDips == expectedDips, "深谷丢失：\(expectedDips) → \(keptDips)")
    }

    @Test("平坦区段降采样后仍均匀铺开")
    func flatSeriesStaysSpread() {
        let source = points((0..<200).map { _ in 42.0 })

        let layout = AppLineChartDownsampling.layout(points: source, maximumVisiblePoints: 20)

        // 全平序列的桶内极值相同，取桶中点而不是全部塌缩到同一位置。
        let distinctFractions = Set(layout.xFractions)
        #expect(distinctFractions.count > 1, "平坦序列被压缩成了单点")
    }

    @Test("可见下标严格递增")
    func visibleIndicesAreAscending() {
        let source = points((0..<300).map { Double(($0 * 7) % 53) })

        let layout = AppLineChartDownsampling.layout(points: source, maximumVisiblePoints: 40)

        #expect(layout.visibleIndices == layout.visibleIndices.sorted())
        #expect(Set(layout.visibleIndices).count == layout.visibleIndices.count, "出现重复下标")
    }

    @Test("可见点与下标一一对应")
    func visiblePointsMatchIndices() {
        let source = points((0..<120).map { Double($0) })

        let layout = AppLineChartDownsampling.layout(points: source, maximumVisiblePoints: 25)

        for (point, index) in zip(layout.visiblePoints, layout.visibleIndices) {
            #expect(point == source[index])
        }
    }

    // MARK: - 兜底路径（关键点多于上限）

    @Test("锯齿数据触发兜底路径后仍不超过上限")
    func bucketedFallbackRespectsLimit() {
        // 交替高低：每个点都是局部极值，关键点数量远多于上限。
        let source = points((0..<300).map { $0.isMultiple(of: 2) ? 1.0 : 100.0 })

        let layout = AppLineChartDownsampling.layout(points: source, maximumVisiblePoints: 40)

        #expect(layout.visiblePoints.count <= 40)
        #expect(layout.isDecimated)
    }

    @Test("兜底路径保留下标不重复")
    func bucketedFallbackHasNoDuplicateIndices() {
        let source = points((0..<300).map { $0.isMultiple(of: 2) ? 1.0 : 100.0 })

        let layout = AppLineChartDownsampling.layout(points: source, maximumVisiblePoints: 40)

        #expect(Set(layout.visibleIndices).count == layout.visibleIndices.count, "出现重复下标")
        #expect(layout.visibleIndices == layout.visibleIndices.sorted())
    }

    @Test("兜底路径保留首尾点")
    func bucketedFallbackKeepsEndpoints() {
        let source = points((0..<300).map { $0.isMultiple(of: 2) ? 1.0 : 100.0 })

        let layout = AppLineChartDownsampling.layout(points: source, maximumVisiblePoints: 40)

        #expect(layout.visibleIndices.first == 0)
        #expect(layout.visibleIndices.last == 299)
    }

    @Test("极小上限时只保留首尾点")
    func tinyLimitKeepsEndpointsOnly() {
        let source = points((0..<300).map { $0.isMultiple(of: 2) ? 1.0 : 100.0 })

        let layout = AppLineChartDownsampling.layout(points: source, maximumVisiblePoints: 2)

        #expect(layout.visibleIndices == [0, 299])
    }

    @Test("上限为 3 时不超过 3 个点")
    func limitOfThreeRespectsBound() {
        let source = points((0..<300).map { $0.isMultiple(of: 2) ? 1.0 : 100.0 })

        let layout = AppLineChartDownsampling.layout(points: source, maximumVisiblePoints: 3)

        #expect(layout.visiblePoints.count <= 3)
        #expect(layout.visibleIndices.first == 0)
        #expect(layout.visibleIndices.last == 299)
    }

    @Test("兜底路径下横坐标仍按原始下标计算")
    func bucketedFallbackUsesOriginalIndicesForX() {
        let source = points((0..<300).map { $0.isMultiple(of: 2) ? 1.0 : 100.0 })

        let layout = AppLineChartDownsampling.layout(points: source, maximumVisiblePoints: 40)

        for (fraction, index) in zip(layout.xFractions, layout.visibleIndices) {
            let expected = Double(index) / Double(299)
            #expect(abs(fraction - expected) < 0.0001)
        }
    }

    // MARK: - 横坐标比例

    @Test("横坐标比例按原始下标计算")
    func xFractionsUseOriginalIndices() {
        let source = points((0..<300).map { Double($0) })

        let layout = AppLineChartDownsampling.layout(points: source, maximumVisiblePoints: 20)

        for (fraction, index) in zip(layout.xFractions, layout.visibleIndices) {
            let expected = Double(index) / Double(299)
            #expect(abs(fraction - expected) < 0.0001)
        }
    }

    @Test("横坐标比例覆盖 0 到 1")
    func xFractionsSpanFullRange() {
        let source = points((0..<300).map { Double($0) })

        let layout = AppLineChartDownsampling.layout(points: source, maximumVisiblePoints: 20)

        #expect(layout.xFractions.first == 0)
        #expect(layout.xFractions.last == 1)
    }

    @Test("未降采样时横坐标比例与原始数量一致")
    func xFractionsMatchEvenSpacingWithoutDecimation() {
        let source = points([1, 2, 3, 4, 5])

        let layout = AppLineChartDownsampling.layout(points: source, maximumVisiblePoints: nil)

        #expect(layout.xFractions == [0, 0.25, 0.5, 0.75, 1])
    }

    @Test("单点时横坐标落在中点")
    func singlePointIsCentered() {
        let source = points([7])

        let layout = AppLineChartDownsampling.layout(points: source, maximumVisiblePoints: nil)

        #expect(layout.xFractions == [0.5])
    }

    @Test("空数组没有横坐标")
    func emptySeriesHasNoFractions() {
        let layout = AppLineChartDownsampling.layout(points: [], maximumVisiblePoints: 10)

        #expect(layout.xFractions.isEmpty)
        #expect(layout.visiblePoints.isEmpty)
        #expect(layout.originalCount == 0)
    }

    // MARK: - 点样式

    @Test("始终绘制圆点")
    func alwaysStyleDrawsPoints() {
        let chartPoints = (0..<100).map { CGPoint(x: Double($0), y: 0) }

        #expect(AppLineChart.shouldDrawPoints(style: .always, chartPoints: chartPoints))
    }

    @Test("从不绘制圆点")
    func neverStyleSkipsPoints() {
        let chartPoints = (0..<3).map { CGPoint(x: Double($0) * 100, y: 0) }

        #expect(AppLineChart.shouldDrawPoints(style: .never, chartPoints: chartPoints) == false)
    }

    @Test("自动模式在间距充足时绘制圆点")
    func automaticStyleDrawsPointsWhenSpacious() {
        let chartPoints = (0..<10).map { CGPoint(x: Double($0) * 40, y: 0) }

        #expect(AppLineChart.shouldDrawPoints(style: .automatic, chartPoints: chartPoints))
    }

    @Test("自动模式在间距不足时不绘制圆点")
    func automaticStyleSkipsPointsWhenCrowded() {
        // 300 个点挤在 300 点宽度里，间距仅 1 点，圆点必然重叠成锯齿带。
        let chartPoints = (0..<300).map { CGPoint(x: Double($0), y: 0) }

        #expect(AppLineChart.shouldDrawPoints(style: .automatic, chartPoints: chartPoints) == false)
    }

    @Test("自动模式对单个点绘制圆点")
    func automaticStyleDrawsSinglePoint() {
        #expect(AppLineChart.shouldDrawPoints(style: .automatic, chartPoints: [CGPoint(x: 0, y: 0)]))
    }
}
