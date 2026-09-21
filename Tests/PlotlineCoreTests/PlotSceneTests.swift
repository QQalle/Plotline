import XCTest

@testable import PlotlineCore

final class PlotSceneTests: XCTestCase {
  func testZonesSupportOpenBoundsAndRejectInvalidRanges() throws {
    let z1 = try XCTUnwrap(PlotZone(id: "z1", label: "Z1", upperBound: 120))
    let z5 = try XCTUnwrap(PlotZone(id: "z5", label: "Z5", lowerBound: 170))

    XCTAssertTrue(z1.contains(80))
    XCTAssertTrue(z1.contains(120))
    XCTAssertFalse(z1.contains(121))
    XCTAssertTrue(z5.contains(190))
    XCTAssertFalse(z5.contains(169))
    XCTAssertNil(PlotZone(id: "invalid", label: "Invalid", lowerBound: 150, upperBound: 150))
    XCTAssertNil(PlotZone(id: "invalid", label: "Invalid", lowerBound: .infinity))
  }

  func testSceneKeepsZonesOutOfAutomaticDataDomain() throws {
    let zone = try XCTUnwrap(
      PlotZone(id: "z3", label: "Z3", lowerBound: 140, upperBound: 160))
    let scene = PlotScene(
      series: [
        PlotSeries(
          id: "heart-rate",
          name: "Heart rate",
          data: .line([PlotSample(x: 0, y: 130), PlotSample(x: 1, y: 150)])
        )
      ],
      zones: [zone]
    )

    XCTAssertEqual(scene.zones, [zone])
    XCTAssertEqual(scene.resolvedYDomain?.lowerBound, 130)
    XCTAssertEqual(scene.resolvedYDomain?.upperBound, 150)
  }

  func testAutomaticDomainsIgnoreGaps() {
    let scene = PlotScene(series: [
      PlotSeries(
        id: "pace",
        name: "Pace",
        data: .line([
          PlotSample(x: 0, y: 6),
          PlotSample(x: 100, y: nil),
          PlotSample(x: 200, y: 5),
        ])
      )
    ])

    XCTAssertEqual(scene.automaticXDomain?.lowerBound, 0)
    XCTAssertEqual(scene.automaticXDomain?.upperBound, 200)
    XCTAssertEqual(scene.automaticYDomain?.lowerBound, 5)
    XCTAssertEqual(scene.automaticYDomain?.upperBound, 6)
  }

  func testCandleDomainIncludesTrueHighAndLow() {
    let scene = PlotScene(series: [
      PlotSeries(
        id: "candles",
        name: "Candles",
        data: .candles([
          PlotCandle(x: 1, open: 10, high: 15, low: 7, close: 12)
        ])
      )
    ])

    XCTAssertEqual(scene.automaticYDomain?.lowerBound, 7)
    XCTAssertEqual(scene.automaticYDomain?.upperBound, 15)
  }

  func testAutomaticDomainUsesPaddingButExplicitDomainDoesNot() throws {
    let explicit = try XCTUnwrap(PlotDomain(lowerBound: 0, upperBound: 20))
    let samples = [PlotSample(x: 0, y: 10), PlotSample(x: 10, y: 20)]
    let automatic = PlotScene(
      yAxis: PlotAxis(domainPadding: 0.1),
      series: [PlotSeries(id: "line", name: "Line", data: .line(samples))]
    )
    let fixed = PlotScene(
      yAxis: PlotAxis(domain: explicit, domainPadding: 0.5),
      series: [PlotSeries(id: "line", name: "Line", data: .line(samples))]
    )

    XCTAssertEqual(automatic.resolvedYDomain?.lowerBound, 9)
    XCTAssertEqual(automatic.resolvedYDomain?.upperBound, 21)
    XCTAssertEqual(fixed.resolvedYDomain, explicit)
  }

  func testViewportOverridesAxisAndAutomaticDomains() throws {
    let axisDomain = try XCTUnwrap(PlotDomain(lowerBound: 0, upperBound: 100))
    let visibleDomain = try XCTUnwrap(PlotDomain(lowerBound: 40, upperBound: 60))
    let scene = PlotScene(
      xAxis: PlotAxis(domain: axisDomain),
      series: [
        PlotSeries(
          id: "line",
          name: "Line",
          data: .line([PlotSample(x: 0, y: 0), PlotSample(x: 100, y: 1)])
        )
      ],
      viewport: PlotViewport(xDomain: visibleDomain)
    )

    XCTAssertEqual(scene.resolvedXDomain, visibleDomain)
  }
}
