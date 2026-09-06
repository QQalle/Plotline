import XCTest

@testable import PlotlineCore

final class PlotSceneTests: XCTestCase {
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
