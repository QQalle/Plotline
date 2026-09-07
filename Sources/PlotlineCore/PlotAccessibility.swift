import Foundation

public struct PlotAccessibilitySeriesSummary: Identifiable, Sendable, Hashable {
  public let id: String
  public let name: String
  public let valueCount: Int
  public let minimumValue: Double?
  public let maximumValue: Double?
  public let latestValue: PlotDataValue?

  public init(
    id: String,
    name: String,
    valueCount: Int,
    minimumValue: Double?,
    maximumValue: Double?,
    latestValue: PlotDataValue?
  ) {
    self.id = id
    self.name = name
    self.valueCount = valueCount
    self.minimumValue = minimumValue
    self.maximumValue = maximumValue
    self.latestValue = latestValue
  }
}

public struct PlotAccessibilityAnnotationSummary: Identifiable, Sendable, Hashable {
  public let id: String
  public let label: String
  public let lowerX: Double
  public let upperX: Double

  public init(id: String, label: String, lowerX: Double, upperX: Double) {
    self.id = id
    self.label = label
    self.lowerX = lowerX
    self.upperX = upperX
  }
}

public struct PlotAccessibilityMetadata: Sendable, Hashable {
  public let label: String
  public let xAxisLabel: String
  public let yAxisLabel: String
  public let xDomain: PlotDomain?
  public let yDomain: PlotDomain?
  public let series: [PlotAccessibilitySeriesSummary]
  public let annotations: [PlotAccessibilityAnnotationSummary]
  public let summary: String
  public let selectionSummary: String?

  public init(
    label: String,
    xAxisLabel: String,
    yAxisLabel: String,
    xDomain: PlotDomain?,
    yDomain: PlotDomain?,
    series: [PlotAccessibilitySeriesSummary],
    annotations: [PlotAccessibilityAnnotationSummary],
    summary: String,
    selectionSummary: String?
  ) {
    self.label = label
    self.xAxisLabel = xAxisLabel
    self.yAxisLabel = yAxisLabel
    self.xDomain = xDomain
    self.yDomain = yDomain
    self.series = series
    self.annotations = annotations
    self.summary = summary
    self.selectionSummary = selectionSummary
  }
}

public enum PlotAccessibilityBuilder {
  public static func metadata(
    for scene: PlotScene,
    selection: PlotSelection? = nil,
    normalization: PlotNormalizationOptions = .default
  ) -> PlotAccessibilityMetadata {
    let series = scene.series.map {
      seriesSummary(PlotDataNormalizer.normalize($0, options: normalization).series)
    }
    let annotations = scene.annotations.compactMap {
      annotation -> PlotAccessibilityAnnotationSummary? in
      switch annotation {
      case .xRange(let id, let lower, let upper, let label):
        guard lower.isFinite, upper.isFinite else { return nil }
        return PlotAccessibilityAnnotationSummary(
          id: id,
          label: label ?? "Range",
          lowerX: min(lower, upper),
          upperX: max(lower, upper)
        )
      case .xMarker(let id, let value, let label):
        guard value.isFinite else { return nil }
        return PlotAccessibilityAnnotationSummary(
          id: id,
          label: label ?? "Marker",
          lowerX: value,
          upperX: value
        )
      }
    }
    let populatedSeries = series.filter { $0.valueCount > 0 }
    let summary = summaryText(
      scene: scene, series: populatedSeries, annotationCount: annotations.count)
    let selectionSummary = selection.map { selectionText($0, scene: scene) }

    return PlotAccessibilityMetadata(
      label: scene.accessibilityLabel,
      xAxisLabel: scene.xAxis.label,
      yAxisLabel: scene.yAxis.label,
      xDomain: scene.resolvedXDomain,
      yDomain: scene.resolvedYDomain,
      series: series,
      annotations: annotations,
      summary: summary,
      selectionSummary: selectionSummary
    )
  }

  private static func seriesSummary(_ series: PlotSeries) -> PlotAccessibilitySeriesSummary {
    let points: [PlotDataValue]
    switch series.data {
    case .line(let samples), .area(let samples, _):
      points = samples.compactMap {
        guard $0.isFinitePoint, let y = $0.y else { return nil }
        return PlotDataValue(x: $0.x, y: y)
      }
    case .candles(let candles):
      points = candles.map { PlotDataValue(x: $0.x, y: $0.close) }
    }
    return PlotAccessibilitySeriesSummary(
      id: series.id,
      name: series.name,
      valueCount: points.count,
      minimumValue: series.finiteYValues.min(),
      maximumValue: series.finiteYValues.max(),
      latestValue: points.last
    )
  }

  private static func summaryText(
    scene: PlotScene,
    series: [PlotAccessibilitySeriesSummary],
    annotationCount: Int
  ) -> String {
    guard !series.isEmpty else { return "No graph data" }
    var components = [
      "\(series.count) data series",
      "\(series.reduce(0) { $0 + $1.valueCount }) values",
    ]
    if let domain = scene.resolvedXDomain {
      components.append(
        "from \(scene.xAxis.formatter(domain.lowerBound)) to \(scene.xAxis.formatter(domain.upperBound))"
      )
    }
    if annotationCount > 0 {
      components.append("\(annotationCount) \(annotationCount == 1 ? "annotation" : "annotations")")
    }
    return components.joined(separator: ", ")
  }

  private static func selectionText(_ selection: PlotSelection, scene: PlotScene) -> String {
    let x = scene.xAxis.formatter(selection.x)
    let values = selection.values.map {
      "\($0.seriesName) \(scene.yAxis.formatter($0.y))"
    }
    return ([x] + values).joined(separator: ", ")
  }
}
