import XCTest

@testable import PlotlineCore

final class PlotInteractionTests: XCTestCase {
  func testNearestSelectionSnapsToVisibleSampleAndReturnsEverySeries() throws {
    let scene = PlotScene(
      series: [
        PlotSeries(
          id: "pace", name: "Pace",
          data: .line([
            PlotSample(x: 0, y: 6), PlotSample(x: 5, y: 5), PlotSample(x: 10, y: 4),
          ])),
        PlotSeries(
          id: "heart-rate", name: "Heart rate",
          data: .line([
            PlotSample(x: 0, y: 120), PlotSample(x: 5, y: 150), PlotSample(x: 10, y: 170),
          ])),
      ],
      annotations: [.xRange(id: "work", lowerBound: 4, upperBound: 6, label: "Work")]
    )
    let layout = try makeLayout(scene)
    let x = layout.transform.xScale.position(for: 5.4)

    let selection = try XCTUnwrap(
      PlotHitTester.selection(
        at: PlotCoordinate(
          x: x,
          y: layout.transform.plotRect.minY + layout.transform.plotRect.height / 2
        ),
        scene: scene,
        layout: layout
      ))

    XCTAssertEqual(selection.x, 5)
    XCTAssertEqual(selection.values.map(\.seriesID), ["pace", "heart-rate"])
    XCTAssertEqual(selection.values.map(\.y), [5, 150])
    XCTAssertEqual(selection.annotationIDs, ["work"])
  }

  func testInterpolatedSelectionHonorsExplicitGaps() throws {
    let scene = PlotScene(
      series: [
        PlotSeries(
          id: "line", name: "Line",
          data: .line([
            PlotSample(x: 0, y: 0), PlotSample(x: 2, y: 4), PlotSample(x: 3, y: nil),
            PlotSample(x: 4, y: 8), PlotSample(x: 6, y: 12),
          ]))
      ]
    )
    let layout = try makeLayout(scene)
    let options = PlotHitTestOptions(selectionMode: .interpolated)

    let interpolated = try XCTUnwrap(
      PlotHitTester.selection(atX: 1, scene: scene, layout: layout, options: options))
    XCTAssertEqual(try XCTUnwrap(interpolated.values.first?.y), 2, accuracy: 0.000_001)
    XCTAssertEqual(interpolated.values.first?.source, .interpolated)

    XCTAssertNil(PlotHitTester.selection(atX: 3, scene: scene, layout: layout, options: options))
  }

  func testCandleSelectionUsesCloseAndDoesNotReachOutsideViewport() throws {
    let viewport = try XCTUnwrap(PlotDomain(lowerBound: 4, upperBound: 6))
    let scene = PlotScene(
      series: [
        PlotSeries(
          id: "effort", name: "Effort",
          data: .candles([
            PlotCandle(x: 0, open: 2, high: 4, low: 1, close: 3),
            PlotCandle(x: 5, open: 4, high: 8, low: 3, close: 7),
            PlotCandle(x: 10, open: 8, high: 9, low: 5, close: 6),
          ]))
      ],
      viewport: PlotViewport(xDomain: viewport)
    )
    let layout = try makeLayout(scene)
    let selection = try XCTUnwrap(PlotHitTester.selection(atX: 4, scene: scene, layout: layout))

    XCTAssertEqual(selection.x, 5)
    XCTAssertEqual(selection.values.first?.y, 7)
    XCTAssertEqual(selection.values.first?.source, .candleClose)
    XCTAssertEqual(PlotHitTester.selectableXValues(scene: scene, layout: layout), [5])
  }

  func testMarkerHitUsesScreenPointTolerance() throws {
    let domain = try XCTUnwrap(PlotDomain(lowerBound: 0, upperBound: 100))
    let scene = PlotScene(
      xAxis: PlotAxis(domain: domain),
      series: [
        PlotSeries(
          id: "line", name: "Line",
          data: .line([PlotSample(x: 0, y: 0), PlotSample(x: 100, y: 100)]))
      ],
      annotations: [.xMarker(id: "lap", value: 50, label: "Lap")]
    )
    let layout = try makeLayout(scene)
    let markerX = layout.transform.xScale.position(for: 50)

    let selection = try XCTUnwrap(
      PlotHitTester.selection(
        at: PlotCoordinate(
          x: markerX + 5,
          y: layout.transform.plotRect.minY + layout.transform.plotRect.height / 2
        ),
        scene: scene,
        layout: layout,
        options: PlotHitTestOptions(selectionMode: .interpolated, annotationTolerance: 6)
      ))
    XCTAssertEqual(selection.annotationIDs, ["lap"])
  }

  private func makeLayout(_ scene: PlotScene) throws -> PlotLayout {
    try XCTUnwrap(
      PlotLayoutEngine.makeLayout(scene: scene, size: PlotSize(width: 320, height: 200)))
  }
}
