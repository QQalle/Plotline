import Accessibility
import PlotlineCore
import SwiftUI

struct PlotlineChartDescriptor: AXChartDescriptorRepresentable {
  let scene: PlotScene

  func makeChartDescriptor() -> AXChartDescriptor {
    let xDomain = scene.resolvedXDomain ?? PlotDomain(lowerBound: 0, upperBound: 1)!
    let yDomain = scene.resolvedYDomain ?? PlotDomain(lowerBound: 0, upperBound: 1)!
    let xAxis = AXNumericDataAxisDescriptor(
      title: scene.xAxis.label,
      range: xDomain.lowerBound...xDomain.upperBound,
      gridlinePositions: PlotTickGenerator.ticks(for: xDomain, axis: scene.xAxis).map(\.value),
      valueDescriptionProvider: scene.xAxis.formatter.callAsFunction
    )
    let yAxis = AXNumericDataAxisDescriptor(
      title: scene.yAxis.label,
      range: yDomain.lowerBound...yDomain.upperBound,
      gridlinePositions: PlotTickGenerator.ticks(for: yDomain, axis: scene.yAxis).map(\.value),
      valueDescriptionProvider: scene.yAxis.formatter.callAsFunction
    )
    let metadata = PlotAccessibilityBuilder.metadata(for: scene)

    return AXChartDescriptor(
      title: scene.accessibilityLabel,
      summary: metadata.summary,
      xAxis: xAxis,
      yAxis: yAxis,
      series: scene.series.compactMap { seriesDescriptor($0, xDomain: xDomain) }
    )
  }

  private func seriesDescriptor(
    _ series: PlotSeries,
    xDomain: PlotDomain
  ) -> AXDataSeriesDescriptor? {
    let normalized = PlotDataNormalizer.normalize(series).series
    let values: [PlotDataValue]
    switch normalized.data {
    case .line(let samples), .area(let samples, _):
      values = samples.compactMap { sample in
        guard sample.isFinitePoint, xDomain.contains(sample.x), let y = sample.y else { return nil }
        return PlotDataValue(x: sample.x, y: y)
      }
    case .candles(let candles):
      values = candles.compactMap { candle in
        guard candle.isFinite, xDomain.contains(candle.x) else { return nil }
        return PlotDataValue(x: candle.x, y: candle.close)
      }
    }
    guard !values.isEmpty else { return nil }

    let points = sampled(values, maximumCount: 200).map { value in
      AXDataPoint(
        x: value.x,
        y: value.y,
        label: "\(scene.xAxis.formatter(value.x)), \(scene.yAxis.formatter(value.y))"
      )
    }
    return AXDataSeriesDescriptor(name: series.name, isContinuous: true, dataPoints: points)
  }

  private func sampled(_ values: [PlotDataValue], maximumCount: Int) -> [PlotDataValue] {
    guard values.count > maximumCount, maximumCount >= 2 else { return values }
    let lastIndex = values.count - 1
    return (0..<maximumCount).map { slot in
      let index = Int(round(Double(slot) * Double(lastIndex) / Double(maximumCount - 1)))
      return values[index]
    }
  }
}
