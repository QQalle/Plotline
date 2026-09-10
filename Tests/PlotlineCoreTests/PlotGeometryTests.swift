import XCTest

@testable import PlotlineCore

final class PlotGeometryTests: XCTestCase {
  func testDownsamplingPreservesEndpointsAndExtremaWithinBudget() {
    var samples = (0..<100).map { PlotSample(x: Double($0), y: Double($0 % 7)) }
    samples[50].y = 100
    samples[51].y = -100

    let result = PlotDownsampler.extremaPreserving(samples, targetCount: 6)

    XCTAssertLessThanOrEqual(result.count, 6)
    XCTAssertEqual(result.first, samples.first)
    XCTAssertEqual(result.last, samples.last)
    XCTAssertTrue(result.contains(samples[50]))
    XCTAssertTrue(result.contains(samples[51]))
  }

  func testPolylineAndPolygonAreClippedToPlotRect() {
    let rect = PlotRect(minX: 0, minY: 0, width: 100, height: 100)
    let line = PlotClipper.clipPolyline(
      [
        PlotCoordinate(x: -10, y: 50),
        PlotCoordinate(x: 110, y: 50),
      ], to: rect)
    let polygon = PlotClipper.clipPolygon(
      [
        PlotCoordinate(x: -10, y: -10),
        PlotCoordinate(x: 110, y: -10),
        PlotCoordinate(x: 110, y: 110),
        PlotCoordinate(x: -10, y: 110),
      ], to: rect)

    XCTAssertEqual(line, [[PlotCoordinate(x: 0, y: 50), PlotCoordinate(x: 100, y: 50)]])
    XCTAssertFalse(polygon.isEmpty)
    XCTAssertTrue(polygon.allSatisfy(rect.contains))
  }

  func testGeometryKeepsGapsAndAlignsAnnotationsToSharedTransform() throws {
    let xDomain = try XCTUnwrap(PlotDomain(lowerBound: 0, upperBound: 10))
    let yDomain = try XCTUnwrap(PlotDomain(lowerBound: 0, upperBound: 10))
    let scene = PlotScene(
      xAxis: PlotAxis(domain: xDomain),
      yAxis: PlotAxis(domain: yDomain),
      series: [
        PlotSeries(
          id: "line", name: "Line",
          data: .line([
            PlotSample(x: 0, y: 1),
            PlotSample(x: 4, y: 4),
            PlotSample(x: 5, y: nil),
            PlotSample(x: 6, y: 6),
            PlotSample(x: 10, y: 9),
          ]))
      ],
      annotations: [
        .xRange(id: "range", lowerBound: 2, upperBound: 4, label: "Range"),
        .xMarker(id: "marker", value: 6, label: "Marker"),
      ]
    )
    let layout = try XCTUnwrap(
      PlotLayoutEngine.makeLayout(
        scene: scene,
        size: PlotSize(width: 300, height: 200)
      ))
    let geometry = PlotGeometryBuilder.makeGeometry(scene: scene, layout: layout)

    guard case .line(let line) = geometry.series[0].shape else {
      return XCTFail("Expected line geometry")
    }
    XCTAssertEqual(line.segments.count, 2)
    XCTAssertEqual(
      geometry.series[0].endpoint,
      layout.transform.coordinate(x: 10, y: 9)
    )

    guard case .xRange(_, let minX, let maxX, _) = geometry.annotations[0],
      case .xMarker(_, let markerX, _) = geometry.annotations[1]
    else {
      return XCTFail("Expected range and marker geometry")
    }
    XCTAssertEqual(minX, layout.transform.xScale.position(for: 2), accuracy: 0.000_001)
    XCTAssertEqual(maxX, layout.transform.xScale.position(for: 4), accuracy: 0.000_001)
    XCTAssertEqual(markerX, layout.transform.xScale.position(for: 6), accuracy: 0.000_001)
  }

  func testEndpointUsesLastFiniteVisibleSampleAndSkipsCandles() throws {
    let domain = try XCTUnwrap(PlotDomain(lowerBound: 0, upperBound: 10))
    let scene = PlotScene(
      xAxis: PlotAxis(domain: domain),
      yAxis: PlotAxis(domain: domain),
      series: [
        PlotSeries(
          id: "line",
          name: "Line",
          data: .line([
            PlotSample(x: 2, y: 3),
            PlotSample(x: 8, y: 7),
            PlotSample(x: 9, y: nil),
          ])
        ),
        PlotSeries(
          id: "candles",
          name: "Candles",
          data: .candles([PlotCandle(x: 5, open: 4, high: 6, low: 3, close: 5)])
        ),
      ]
    )
    let layout = try XCTUnwrap(
      PlotLayoutEngine.makeLayout(scene: scene, size: PlotSize(width: 300, height: 200))
    )
    let geometry = PlotGeometryBuilder.makeGeometry(scene: scene, layout: layout)

    XCTAssertEqual(geometry.series[0].endpoint, layout.transform.coordinate(x: 8, y: 7))
    XCTAssertNil(geometry.series[1].endpoint)
  }

  func testAreaCrossingVisibleDomainStillProducesClippedFill() throws {
    let domain = try XCTUnwrap(PlotDomain(lowerBound: 0, upperBound: 10))
    let scene = PlotScene(
      xAxis: PlotAxis(domain: domain),
      yAxis: PlotAxis(domain: domain),
      series: [
        PlotSeries(
          id: "area",
          name: "Area",
          data: .area([PlotSample(x: 0, y: 20), PlotSample(x: 10, y: 20)], baseline: .zero)
        )
      ]
    )
    let layout = try XCTUnwrap(
      PlotLayoutEngine.makeLayout(
        scene: scene,
        size: PlotSize(width: 300, height: 200)
      ))
    let geometry = PlotGeometryBuilder.makeGeometry(scene: scene, layout: layout)

    guard case .area(let area) = geometry.series[0].shape else {
      return XCTFail("Expected area geometry")
    }
    XCTAssertEqual(area.polygons.count, 1)
    XCTAssertTrue(area.polygons[0].allSatisfy(layout.transform.plotRect.contains))
  }
}
