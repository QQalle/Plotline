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
}
