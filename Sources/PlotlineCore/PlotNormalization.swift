import Foundation

public enum PlotDuplicateXPolicy: Sendable, Hashable {
  case keepFirst
  case keepLast
  case average
}

public struct PlotNormalizationOptions: Sendable, Hashable {
  public var sortByX: Bool
  public var duplicateXPolicy: PlotDuplicateXPolicy

  public init(sortByX: Bool = true, duplicateXPolicy: PlotDuplicateXPolicy = .keepLast) {
    self.sortByX = sortByX
    self.duplicateXPolicy = duplicateXPolicy
  }

  public static let `default` = PlotNormalizationOptions()
}

public struct PlotNormalizationResult: Sendable, Hashable {
  public let series: PlotSeries
  public let droppedValueCount: Int
  public let collapsedDuplicateCount: Int

  public init(series: PlotSeries, droppedValueCount: Int, collapsedDuplicateCount: Int) {
    self.series = series
    self.droppedValueCount = droppedValueCount
    self.collapsedDuplicateCount = collapsedDuplicateCount
  }
}

public enum PlotDataNormalizer {
  public static func normalize(
    _ series: PlotSeries,
    options: PlotNormalizationOptions = .default
  ) -> PlotNormalizationResult {
    switch series.data {
    case .line(let samples):
      let normalized = normalizeSamples(samples, options: options)
      return PlotNormalizationResult(
        series: PlotSeries(
          id: series.id,
          name: series.name,
          data: .line(normalized.samples),
          opacity: series.opacity
        ),
        droppedValueCount: normalized.dropped,
        collapsedDuplicateCount: normalized.duplicates
      )

    case .area(let samples, let baseline):
      let normalized = normalizeSamples(samples, options: options)
      return PlotNormalizationResult(
        series: PlotSeries(
          id: series.id,
          name: series.name,
          data: .area(normalized.samples, baseline: baseline),
          opacity: series.opacity
        ),
        droppedValueCount: normalized.dropped,
        collapsedDuplicateCount: normalized.duplicates
      )

    case .candles(let candles):
      let finite = candles.enumerated().filter { $0.element.isValid }
      let dropped = candles.count - finite.count
      let ordered =
        options.sortByX
        ? finite.sorted { lhs, rhs in
          lhs.element.x == rhs.element.x ? lhs.offset < rhs.offset : lhs.element.x < rhs.element.x
        }
        : finite
      let collapsed = collapseCandles(ordered.map(\.element), policy: options.duplicateXPolicy)
      return PlotNormalizationResult(
        series: PlotSeries(
          id: series.id,
          name: series.name,
          data: .candles(collapsed.values),
          opacity: series.opacity
        ),
        droppedValueCount: dropped,
        collapsedDuplicateCount: collapsed.duplicateCount
      )
    }
  }

  public static func finiteSegments(_ samples: [PlotSample]) -> [[PlotSample]] {
    var result: [[PlotSample]] = []
    var current: [PlotSample] = []

    for sample in samples {
      if sample.isFinitePoint {
        current.append(sample)
      } else if !current.isEmpty {
        result.append(current)
        current = []
      }
    }
    if !current.isEmpty { result.append(current) }
    return result
  }

  private static func normalizeSamples(
    _ samples: [PlotSample],
    options: PlotNormalizationOptions
  ) -> (samples: [PlotSample], dropped: Int, duplicates: Int) {
    let droppedCount = samples.count { sample in
      !sample.x.isFinite || (sample.y != nil && sample.y?.isFinite != true)
    }
    let segments = finiteSegments(samples)
    var normalized: [PlotSample] = []
    var duplicateCount = 0

    for (segmentIndex, segment) in segments.enumerated() {
      let indexed = segment.enumerated().map { (offset: $0.offset, sample: $0.element) }
      let ordered =
        options.sortByX
        ? indexed.sorted { lhs, rhs in
          lhs.sample.x == rhs.sample.x ? lhs.offset < rhs.offset : lhs.sample.x < rhs.sample.x
        }
        : indexed
      let collapsed = collapseSamples(ordered.map(\.sample), policy: options.duplicateXPolicy)
      duplicateCount += collapsed.duplicateCount

      if segmentIndex > 0, !normalized.isEmpty {
        normalized.append(PlotSample(x: collapsed.values.first?.x ?? 0, y: nil))
      }
      normalized.append(contentsOf: collapsed.values)
    }

    return (
      samples: normalized,
      dropped: droppedCount,
      duplicates: duplicateCount
    )
  }

  private static func collapseSamples(
    _ samples: [PlotSample],
    policy: PlotDuplicateXPolicy
  ) -> (values: [PlotSample], duplicateCount: Int) {
    var result: [PlotSample] = []
    var index = 0
    var duplicates = 0

    while index < samples.count {
      let x = samples[index].x
      var groupEnd = index + 1
      while groupEnd < samples.count, samples[groupEnd].x == x { groupEnd += 1 }
      let group = Array(samples[index..<groupEnd])
      duplicates += max(0, group.count - 1)

      switch policy {
      case .keepFirst:
        result.append(group[0])
      case .keepLast:
        result.append(group[group.count - 1])
      case .average:
        let values = group.compactMap(\.y)
        result.append(PlotSample(x: x, y: values.reduce(0, +) / Double(values.count)))
      }
      index = groupEnd
    }
    return (result, duplicates)
  }

  private static func collapseCandles(
    _ candles: [PlotCandle],
    policy: PlotDuplicateXPolicy
  ) -> (values: [PlotCandle], duplicateCount: Int) {
    var result: [PlotCandle] = []
    var index = 0
    var duplicates = 0

    while index < candles.count {
      let x = candles[index].x
      var groupEnd = index + 1
      while groupEnd < candles.count, candles[groupEnd].x == x { groupEnd += 1 }
      let group = Array(candles[index..<groupEnd])
      duplicates += max(0, group.count - 1)

      switch policy {
      case .keepFirst:
        result.append(group[0])
      case .keepLast:
        result.append(group[group.count - 1])
      case .average:
        result.append(
          PlotCandle(
            x: x,
            open: group[0].open,
            high: group.map(\.high).max()!,
            low: group.map(\.low).min()!,
            close: group[group.count - 1].close
          ))
      }
      index = groupEnd
    }
    return (result, duplicates)
  }
}
