import XCTest
@testable import Plotline

final class PlotlineTests: XCTestCase {
    func testPublicModuleReexportsCoreTypes() {
        let scene = PlotScene(series: [])
        XCTAssertEqual(scene.accessibilityLabel, "Graph")
    }
}
