import Foundation
import SwiftUI
import Testing

@testable import LumiUI

/// 横轴标签与刻度的回归测试。
///
/// 关键不变式：横轴标签的语义必须与横轴的实际含义一致。
/// 按请求排列的曲线其横轴是请求序号，标成日期会让标签与布局互相矛盾。
struct AppLineChartAxisTests {

    // MARK: - Helpers

    private func points(_ count: Int) -> [AppLineChartPoint] {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        return (0..<count).map { index in
            AppLineChartPoint(
                date: base.addingTimeInterval(Double(index) * 60),
                value: Double(index)
            )
        }
    }

    // MARK: - Label Styles

    @Test("序号样式按 1 起始编号")
    func indexStyleCountsFromOne() {
        let style = AppLineChartAxisStyle.index
        let date = Date(timeIntervalSince1970: 0)

        #expect(style.label(index: 0, date: date) == "#1")
        #expect(style.label(index: 11, date: date) == "#12")
    }

    @Test("日期样式输出月/日")
    func dateStyleFormatsMonthAndDay() {
        let style = AppLineChartAxisStyle.date
        // 2026-11-12
        var components = DateComponents()
        components.year = 2026
        components.month = 11
        components.day = 12
        let date = Calendar.current.date(from: components)!

        #expect(style.label(index: 0, date: date) == "11/12")
    }

    @Test("自定义样式使用调用方提供的格式")
    func customStyleUsesCallerFormat() {
        let style = AppLineChartAxisStyle.custom { index in "第 \(index + 1) 次" }
        let date = Date(timeIntervalSince1970: 0)

        #expect(style.label(index: 0, date: date) == "第 1 次")
        #expect(style.label(index: 41, date: date) == "第 42 次")
    }

    // MARK: - Tick Layout

    @Test("刻度数量不超过预期数量")
    func tickCountIsCapped() {
        let ticks = AppLineChartTickLayout.ticks(
            points: points(100),
            visibleRange: 0..<100,
            axisStyle: .index
        )

        #expect(ticks.count <= AppLineChartTickLayout.preferredTickCount)
    }

    @Test("刻度数量不超过可见点数")
    func tickCountNeverExceedsVisiblePoints() {
        let ticks = AppLineChartTickLayout.ticks(
            points: points(3),
            visibleRange: 0..<3,
            axisStyle: .index
        )

        #expect(ticks.count <= 3)
    }

    @Test("刻度落在可见范围内")
    func ticksStayWithinVisibleRange() {
        let ticks = AppLineChartTickLayout.ticks(
            points: points(1000),
            visibleRange: 100..<200,
            axisStyle: .index
        )

        for tick in ticks {
            #expect(tick.pointIndex >= 100)
            #expect(tick.pointIndex < 200)
        }
    }

    @Test("刻度下标严格递增")
    func tickIndicesAreAscending() {
        let ticks = AppLineChartTickLayout.ticks(
            points: points(1000),
            visibleRange: 0..<1000,
            axisStyle: .index
        )

        #expect(ticks.map(\.pointIndex) == ticks.map(\.pointIndex).sorted())
        #expect(Set(ticks.map(\.pointIndex)).count == ticks.count, "出现重复刻度")
    }

    @Test("刻度均匀分布在可见范围内")
    func ticksAreEvenlySpread() {
        let ticks = AppLineChartTickLayout.ticks(
            points: points(101),
            visibleRange: 0..<101,
            axisStyle: .index,
            preferredCount: 5
        )

        #expect(ticks.count == 5)
        // 首尾必须落在可见范围的两端。
        #expect(ticks.first?.pointIndex == 0)
        #expect(ticks.last?.pointIndex == 100)
        // 相邻间隔基本相等。
        let gaps = zip(ticks, ticks.dropFirst()).map { $1.pointIndex - $0.pointIndex }
        #expect(Set(gaps).count == 1, "刻度间隔不均匀：\(gaps)")
    }

    @Test("序号样式下刻度标签是序号")
    func indexTicksCarryIndexLabels() {
        let ticks = AppLineChartTickLayout.ticks(
            points: points(50),
            visibleRange: 0..<50,
            axisStyle: .index
        )

        for tick in ticks {
            #expect(tick.text == "#\(tick.pointIndex + 1)")
        }
    }

    @Test("滚动后刻度反映当前可见区间的序号")
    func ticksReflectScrolledRange() {
        let ticks = AppLineChartTickLayout.ticks(
            points: points(1000),
            visibleRange: 500..<560,
            axisStyle: .index
        )

        // 第一个刻度应指向可见区间的起点附近。
        #expect(ticks.first?.pointIndex == 500)
        #expect(ticks.first?.text == "#501")
    }

    @Test("空序列没有刻度")
    func emptySeriesHasNoTicks() {
        let ticks = AppLineChartTickLayout.ticks(
            points: [],
            visibleRange: 0..<0,
            axisStyle: .index
        )

        #expect(ticks.isEmpty)
    }

    @Test("可见范围为空时没有刻度")
    func emptyVisibleRangeHasNoTicks() {
        let ticks = AppLineChartTickLayout.ticks(
            points: points(100),
            visibleRange: 50..<50,
            axisStyle: .index
        )

        #expect(ticks.isEmpty)
    }

    @Test("单个可见点只标一个刻度")
    func singleVisiblePointHasOneTick() {
        let ticks = AppLineChartTickLayout.ticks(
            points: points(100),
            visibleRange: 10..<11,
            axisStyle: .index
        )

        #expect(ticks.count == 1)
        #expect(ticks.first?.pointIndex == 10)
        #expect(ticks.first?.text == "#11")
    }

    @Test("刻度下标不越界")
    func tickIndicesStayInBounds() {
        let ticks = AppLineChartTickLayout.ticks(
            points: points(20),
            visibleRange: 0..<1000,
            axisStyle: .index
        )

        for tick in ticks {
            #expect(tick.pointIndex >= 0)
            #expect(tick.pointIndex < 20)
        }
    }
}
