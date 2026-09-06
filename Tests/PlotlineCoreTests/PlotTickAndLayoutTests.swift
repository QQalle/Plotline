import XCTest

@testable import PlotlineCore

final class PlotTickAndLayoutTests: XCTestCase {
  func testNiceTicksUseReadableSteps() throws {
    let domain = try XCTUnwrap(PlotDomain(lowerBound: 3, upperBound: 97))

    XCTAssertEqual(PlotTickGenerator.values(for: domain, targetCount: 5), [20, 40, 60, 80])
    XCTAssertEqual(PlotTickGenerator.niceStep(for: 0.023), 0.02, accuracy: 0.000_001)
  }

  func testLayoutThinsLabelsForNarrowPlots() throws {
    let domain = try XCTUnwrap(PlotDomain(lowerBound: 0, upperBound: 100))
    let scene = PlotScene(
      xAxis: PlotAxis(domain: domain, targetTickCount: 8),
      yAxis: PlotAxis(domain: domain),
      series: []
    )
    let metrics = PlotLayoutMetrics(
      maximumYAxisLabelWidth: 20,
      maximumYAxisLabelHeight: 10,
      maximumXAxisLabelHeight: 10,
      maximumXAxisLabelWidth: 45,
      outerPadding: 5,
      labelSpacing: 5
    )

    let layout = try XCTUnwrap(
      PlotLayoutEngine.makeLayout(
        scene: scene,
        size: PlotSize(width: 140, height: 120),
        metrics: metrics
      ))

    XCTAssertEqual(layout.xTicks.count, 2)
    XCTAssertEqual(layout.xTicks.first?.value, 0)
    XCTAssertEqual(layout.xTicks.last?.value, 100)
  }

  func testTransformRoundTripsAndUsesCartesianYDirection() throws {
    let domain = try XCTUnwrap(PlotDomain(lowerBound: 0, upperBound: 10))
    let scene = PlotScene(
      xAxis: PlotAxis(domain: domain),
      yAxis: PlotAxis(domain: domain),
      series: []
    )
    let layout = try XCTUnwrap(
      PlotLayoutEngine.makeLayout(
        scene: scene,
        size: PlotSize(width: 200, height: 160)
      ))
    let low = try XCTUnwrap(layout.transform.coordinate(x: 0, y: 0))
    let high = try XCTUnwrap(layout.transform.coordinate(x: 10, y: 10))
    let roundTrip = layout.transform.dataValue(at: high)

    XCTAssertLessThan(low.x, high.x)
    XCTAssertGreaterThan(low.y, high.y)
    XCTAssertEqual(roundTrip.x, 10, accuracy: 0.000_001)
    XCTAssertEqual(roundTrip.y, 10, accuracy: 0.000_001)
  }
}
