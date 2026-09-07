import XCTest

@testable import PlotlineCore

final class PlotAccessibilityTests: XCTestCase {
  func testMetadataDescribesSeriesDomainsAndAnnotations() throws {
    let scene = PlotScene(
      xAxis: PlotAxis(label: "Distance", formatter: .number(decimals: 1)),
      yAxis: PlotAxis(label: "Pace", formatter: .number(decimals: 2)),
      series: [
        PlotSeries(
          id: "pace", name: "Pace",
          data: .line([
            PlotSample(x: 0, y: 5.5), PlotSample(x: 1, y: nil), PlotSample(x: 2, y: 4.25),
          ]))
      ],
      annotations: [.xRange(id: "interval", lowerBound: 0.5, upperBound: 1.5, label: "Work")],
      accessibilityLabel: "Run pace graph"
    )

    let metadata = PlotAccessibilityBuilder.metadata(for: scene)

    XCTAssertEqual(metadata.label, "Run pace graph")
    XCTAssertEqual(metadata.xAxisLabel, "Distance")
    XCTAssertEqual(metadata.yAxisLabel, "Pace")
    XCTAssertEqual(metadata.series.first?.valueCount, 2)
    XCTAssertEqual(metadata.series.first?.minimumValue, 4.25)
    XCTAssertEqual(metadata.series.first?.maximumValue, 5.5)
    XCTAssertEqual(metadata.series.first?.latestValue, PlotDataValue(x: 2, y: 4.25))
    XCTAssertEqual(metadata.annotations.first?.label, "Work")
    XCTAssertTrue(metadata.summary.contains("1 data series"))
    XCTAssertTrue(metadata.summary.contains("1 annotation"))
  }

  func testSelectionSummaryUsesAxisFormattersAndSeriesNames() throws {
    let scene = PlotScene(
      xAxis: PlotAxis(formatter: PlotValueFormatter { "x=\(Int($0))" }),
      yAxis: PlotAxis(formatter: PlotValueFormatter { "y=\(Int($0))" }),
      series: [
        PlotSeries(
          id: "effort", name: "Effort",
          data: .line([PlotSample(x: 2, y: 7)]))
      ]
    )
    let layout = try XCTUnwrap(
      PlotLayoutEngine.makeLayout(scene: scene, size: PlotSize(width: 320, height: 200)))
    let selection = try XCTUnwrap(PlotHitTester.selection(atX: 2, scene: scene, layout: layout))

    let metadata = PlotAccessibilityBuilder.metadata(for: scene, selection: selection)

    XCTAssertEqual(metadata.selectionSummary, "x=2, Effort y=7")
  }
}
