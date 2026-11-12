import Foundation
import SwiftUI
import Testing

@testable import LumiUI

/// 固定间距 + 横向滚动的回归测试。
///
/// 核心不变式：**屏幕上的点间距恒定**，不随数据量增长而变密；
/// 数据超出视口时改为滚动，而不是把点挤在一起。
struct AppLineChartGeometryTests {

    // MARK: - Constants

    /// 上下文弹窗的绘图区宽度：360 - 16*2 - 14*2 = 300
    private let plotWidth: CGFloat = 300
    private let inset = EdgeInsets(top: 14, leading: 14, bottom: 24, trailing: 14)

    // MARK: - Fixed Spacing

    @Test("点数少时铺满视口")
    func shortSeriesFillsViewport() {
        let geometry = AppLineChartGeometry.fixedSpacing(
            pointCount: 10,
            viewportWidth: plotWidth + inset.leading + inset.trailing,
            minimumSpacing: 8,
            inset: inset
        )

        // 10 个点铺满 300pt → 间距 33.33pt
        #expect(abs(geometry.pointSpacing - (plotWidth / 9)) < 0.01)
        #expect(geometry.isScrollable == false)
    }

    @Test("点数多时保持固定间距并可滚动")
    func longSeriesKeepsSpacingAndScrolls() {
        let geometry = AppLineChartGeometry.fixedSpacing(
            pointCount: 1000,
            viewportWidth: plotWidth + inset.leading + inset.trailing,
            minimumSpacing: 8,
            inset: inset
        )

        // 最小间距生效：8pt
        #expect(geometry.pointSpacing == 8)
        #expect(geometry.isScrollable)
        // 内容宽度 = 内边距 + 间距 * (点数 - 1)
        #expect(abs(geometry.contentWidth - (inset.leading + 8 * 999 + inset.trailing)) < 0.01)
    }

    @Test("点数再多间距也不会变窄")
    func spacingNeverShrinksWithMorePoints() {
        var previousSpacing: CGFloat = .greatestFiniteMagnitude

        for count in [10, 100, 1000, 10_000, 100_000] {
            let geometry = AppLineChartGeometry.fixedSpacing(
                pointCount: count,
                viewportWidth: plotWidth + inset.leading + inset.trailing,
                minimumSpacing: 8,
                inset: inset
            )
            #expect(geometry.pointSpacing >= 8, "间距在 \(count) 点时变窄了")
            #expect(geometry.pointSpacing <= previousSpacing, "间距随点数增加而变大")
            previousSpacing = geometry.pointSpacing
        }
    }

    @Test("单点时不产生滚动")
    func singlePointDoesNotScroll() {
        let geometry = AppLineChartGeometry.fixedSpacing(
            pointCount: 1,
            viewportWidth: plotWidth + inset.leading + inset.trailing,
            minimumSpacing: 8,
            inset: inset
        )

        #expect(geometry.isScrollable == false)
        #expect(geometry.pointSpacing == 0)
    }

    // MARK: - Positions

    @Test("点的横坐标按固定间距递增")
    func positionsAdvanceByFixedSpacing() {
        let geometry = AppLineChartGeometry.fixedSpacing(
            pointCount: 100,
            viewportWidth: plotWidth + inset.leading + inset.trailing,
            minimumSpacing: 8,
            inset: inset
        )

        for index in 1..<100 {
            let previous = geometry.xPosition(forIndex: index - 1)
            let current = geometry.xPosition(forIndex: index)
            #expect(abs((current - previous) - 8) < 0.001)
        }
    }

    @Test("横坐标反查回正确的点下标")
    func indexLookupIsInverseOfPosition() {
        let geometry = AppLineChartGeometry.fixedSpacing(
            pointCount: 100,
            viewportWidth: plotWidth + inset.leading + inset.trailing,
            minimumSpacing: 8,
            inset: inset
        )

        for index in [0, 1, 37, 98, 99] {
            let x = geometry.xPosition(forIndex: index)
            #expect(geometry.index(forContentX: x) == index)
        }
    }

    @Test("超出范围的横坐标反查返回 nil")
    func indexLookupRejectsOutOfRange() {
        let geometry = AppLineChartGeometry.fixedSpacing(
            pointCount: 10,
            viewportWidth: plotWidth + inset.leading + inset.trailing,
            minimumSpacing: 8,
            inset: inset
        )

        #expect(geometry.index(forContentX: -100) == nil)
        #expect(geometry.index(forContentX: 10_000) == nil)
    }

    // MARK: - Guides

    @Test("参考线落在两点之间")
    func guideSitsBetweenPoints() {
        let geometry = AppLineChartGeometry.fixedSpacing(
            pointCount: 100,
            viewportWidth: plotWidth + inset.leading + inset.trailing,
            minimumSpacing: 8,
            inset: inset
        )

        let guideX = geometry.guideXPosition(afterPointIndex: 10)
        let pointX = geometry.xPosition(forIndex: 10)
        let nextPointX = geometry.xPosition(forIndex: 11)

        #expect(guideX > pointX)
        #expect(guideX < nextPointX)
    }

    @Test("早于首个点的参考线贴在左边缘")
    func guideBeforeFirstPointSitsAtLeftEdge() {
        let geometry = AppLineChartGeometry.fixedSpacing(
            pointCount: 100,
            viewportWidth: plotWidth + inset.leading + inset.trailing,
            minimumSpacing: 8,
            inset: inset
        )

        #expect(geometry.guideXPosition(afterPointIndex: -1) == inset.leading)
    }

    @Test("参考线不会超出绘图区")
    func guideStaysWithinContent() {
        let geometry = AppLineChartGeometry.fixedSpacing(
            pointCount: 100,
            viewportWidth: plotWidth + inset.leading + inset.trailing,
            minimumSpacing: 8,
            inset: inset
        )

        for index in [-1, 0, 50, 98, 99] {
            let x = geometry.guideXPosition(afterPointIndex: index)
            #expect(x >= inset.leading)
            #expect(x <= geometry.contentWidth - inset.trailing)
        }
    }

    // MARK: - Visible Range

    @Test("未滚动时可见范围覆盖视口")
    func visibleRangeCoversViewportAtOrigin() {
        let geometry = AppLineChartGeometry.fixedSpacing(
            pointCount: 1000,
            viewportWidth: plotWidth + inset.leading + inset.trailing,
            minimumSpacing: 8,
            inset: inset
        )

        let range = geometry.visibleRange(scrollOffset: 0)
        #expect(range.lowerBound == 0)
        // 视口宽 328，能放下 41 个点，加上两侧各 1 点的余量。
        #expect(range.upperBound > 40)
    }

    @Test("滚动后可见范围跟随偏移")
    func visibleRangeFollowsScroll() {
        let geometry = AppLineChartGeometry.fixedSpacing(
            pointCount: 1000,
            viewportWidth: plotWidth + inset.leading + inset.trailing,
            minimumSpacing: 8,
            inset: inset
        )

        let range = geometry.visibleRange(scrollOffset: 800)
        #expect(range.lowerBound > 0)
        #expect(range.upperBound <= 1000)
    }

    @Test("可见范围永不越界")
    func visibleRangeStaysInBounds() {
        let geometry = AppLineChartGeometry.fixedSpacing(
            pointCount: 1000,
            viewportWidth: plotWidth + inset.leading + inset.trailing,
            minimumSpacing: 8,
            inset: inset
        )

        for offset in stride(from: 0.0, to: 8000.0, by: 250.0) {
            let range = geometry.visibleRange(scrollOffset: offset)
            #expect(range.lowerBound >= 0)
            #expect(range.upperBound <= 1000)
            #expect(range.upperBound > range.lowerBound)
        }
    }

    @Test("空序列没有可见范围")
    func emptySeriesHasNoVisibleRange() {
        let geometry = AppLineChartGeometry.fixedSpacing(
            pointCount: 0,
            viewportWidth: plotWidth + inset.leading + inset.trailing,
            minimumSpacing: 8,
            inset: inset
        )

        #expect(geometry.visibleRange(scrollOffset: 0).isEmpty)
        #expect(geometry.index(forContentX: 100) == nil)
    }
}
