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
                    PlotSample(x: 200, y: 5)
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
}
