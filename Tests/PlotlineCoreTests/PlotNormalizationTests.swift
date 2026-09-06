import XCTest

@testable import PlotlineCore

final class PlotNormalizationTests: XCTestCase {
  func testSortsAndCollapsesDuplicatesWithoutJoiningAcrossGap() throws {
    let series = PlotSeries(
      id: "heart-rate",
      name: "Heart rate",
      data: .line([
        PlotSample(x: 2, y: 20),
        PlotSample(x: 1, y: 10),
        PlotSample(x: 1, y: 12),
        PlotSample(x: 3, y: nil),
        PlotSample(x: 4, y: 40),
        PlotSample(x: .infinity, y: 50),
      ])
    )

    let result = PlotDataNormalizer.normalize(series)
    guard case .line(let samples) = result.series.data else {
      return XCTFail("Expected line data")
    }

    XCTAssertEqual(
      samples,
      [
        PlotSample(x: 1, y: 12),
        PlotSample(x: 2, y: 20),
        PlotSample(x: 4, y: nil),
        PlotSample(x: 4, y: 40),
      ])
    XCTAssertEqual(result.droppedValueCount, 1)
    XCTAssertEqual(result.collapsedDuplicateCount, 1)
    XCTAssertEqual(PlotDataNormalizer.finiteSegments(samples).count, 2)
  }

  func testAverageDuplicatePolicyAveragesSamplesAndMergesCandles() {
    let line = PlotSeries(
      id: "line",
      name: "Line",
      data: .line([PlotSample(x: 1, y: 4), PlotSample(x: 1, y: 8)])
    )
    let candles = PlotSeries(
      id: "candles",
      name: "Candles",
      data: .candles([
        PlotCandle(x: 1, open: 10, high: 15, low: 8, close: 12),
        PlotCandle(x: 1, open: 12, high: 20, low: 9, close: 18),
      ])
    )
    let options = PlotNormalizationOptions(duplicateXPolicy: .average)

    let lineResult = PlotDataNormalizer.normalize(line, options: options)
    let candleResult = PlotDataNormalizer.normalize(candles, options: options)

    guard case .line(let samples) = lineResult.series.data,
      case .candles(let values) = candleResult.series.data
    else {
      return XCTFail("Unexpected normalized data")
    }
    XCTAssertEqual(samples, [PlotSample(x: 1, y: 6)])
    XCTAssertEqual(values, [PlotCandle(x: 1, open: 10, high: 20, low: 8, close: 18)])
  }

  func testRejectsInvalidCandles() {
    let series = PlotSeries(
      id: "candles",
      name: "Candles",
      data: .candles([
        PlotCandle(x: 1, open: 10, high: 9, low: 8, close: 12),
        PlotCandle(x: 2, open: 10, high: 13, low: 8, close: 12),
      ])
    )

    let result = PlotDataNormalizer.normalize(series)

    guard case .candles(let values) = result.series.data else {
      return XCTFail("Expected candle data")
    }
    XCTAssertEqual(values.count, 1)
    XCTAssertEqual(values[0].x, 2)
    XCTAssertEqual(result.droppedValueCount, 1)
  }
}
