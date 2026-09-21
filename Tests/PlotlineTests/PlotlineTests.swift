import SwiftUI
import XCTest

@testable import Plotline

final class PlotlineTests: XCTestCase {
  func testPublicModuleReexportsCoreTypes() {
    let scene = PlotScene(series: [])
    XCTAssertEqual(scene.accessibilityLabel, "Graph")
  }

  @MainActor
  func testInteractiveInitializerAcceptsSelectionBindingAndCallback() {
    let scene = PlotScene(
      series: [
        PlotSeries(id: "line", name: "Line", data: .line([PlotSample(x: 0, y: 1)]))
      ]
    )
    let view = PlotlineView(
      scene: scene,
      selection: .constant(nil),
      interaction: PlotlineInteractionConfiguration(persistence: .persistent)
    ) { _ in }

    XCTAssertNotNil(view.body)
  }

  @MainActor
  func testLiveInitializerBuildsView() {
    let scene = PlotScene(
      series: [
        PlotSeries(
          id: "line",
          name: "Line",
          data: .line([PlotSample(x: 0, y: 1), PlotSample(x: 1, y: 2)])
        )
      ]
    )
    let view = PlotlineView(scene: scene, isLive: true)

    XCTAssertNotNil(view.body)
  }

  @MainActor
  func testZoneStyleAndMinimalGridBuildView() throws {
    let zone = try XCTUnwrap(
      PlotZone(id: "z1", label: "Z1", lowerBound: nil, upperBound: 120))
    let scene = PlotScene(
      series: [
        PlotSeries(
          id: "heart-rate",
          name: "Heart rate",
          data: .line([PlotSample(x: 0, y: 100), PlotSample(x: 1, y: 115)])
        )
      ],
      zones: [zone]
    )
    let style = PlotlineStyle(
      zoneColors: ["z1": .blue],
      gridVisibility: .none,
      yAxisPosition: .trailing,
      showsYAxisLabels: false,
      showsAxisTitles: false,
      showsZoneBoundaryLabels: true
    )

    XCTAssertNotNil(PlotlineView(scene: scene, style: style).body)
  }
}
