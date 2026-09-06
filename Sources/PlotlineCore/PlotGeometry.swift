import Foundation

public struct PlotLineGeometry: Sendable, Hashable {
  public let segments: [[PlotCoordinate]]

  public init(segments: [[PlotCoordinate]]) {
    self.segments = segments
  }
}

public struct PlotAreaGeometry: Sendable, Hashable {
  public let polygons: [[PlotCoordinate]]
  public let line: PlotLineGeometry

  public init(polygons: [[PlotCoordinate]], line: PlotLineGeometry) {
    self.polygons = polygons
    self.line = line
  }
}

public struct PlotCandleGeometry: Sendable, Hashable {
  public let x: Double
  public let highY: Double
  public let lowY: Double
  public let openY: Double
  public let closeY: Double
  public let bodyWidth: Double
  public let isRising: Bool

  public init(
    x: Double,
    highY: Double,
    lowY: Double,
    openY: Double,
    closeY: Double,
    bodyWidth: Double,
    isRising: Bool
  ) {
    self.x = x
    self.highY = highY
    self.lowY = lowY
    self.openY = openY
    self.closeY = closeY
    self.bodyWidth = bodyWidth
    self.isRising = isRising
  }
}

public enum PlotSeriesShape: Sendable, Hashable {
  case line(PlotLineGeometry)
  case area(PlotAreaGeometry)
  case candles([PlotCandleGeometry])
}

public struct PlotResolvedSeriesGeometry: Identifiable, Sendable, Hashable {
  public let id: String
  public let name: String
  public let opacity: Double
  public let shape: PlotSeriesShape

  public init(id: String, name: String, opacity: Double, shape: PlotSeriesShape) {
    self.id = id
    self.name = name
    self.opacity = opacity
    self.shape = shape
  }
}

public enum PlotAnnotationGeometry: Identifiable, Sendable, Hashable {
  case xRange(id: String, minX: Double, maxX: Double, label: String?)
  case xMarker(id: String, x: Double, label: String?)

  public var id: String {
    switch self {
    case .xRange(let id, _, _, _), .xMarker(let id, _, _): id
    }
  }
}

public struct PlotGeometryOptions: Sendable, Hashable {
  public var samplesPerPixel: Double
  public var normalization: PlotNormalizationOptions

  public init(
    samplesPerPixel: Double = 2,
    normalization: PlotNormalizationOptions = .default
  ) {
    self.samplesPerPixel = samplesPerPixel.isFinite ? max(0.25, samplesPerPixel) : 2
    self.normalization = normalization
  }

  public static let `default` = PlotGeometryOptions()
}

public struct PlotGeometryResult: Sendable, Hashable {
  public let series: [PlotResolvedSeriesGeometry]
  public let annotations: [PlotAnnotationGeometry]
  public let droppedValueCount: Int
  public let collapsedDuplicateCount: Int

  public init(
    series: [PlotResolvedSeriesGeometry],
    annotations: [PlotAnnotationGeometry],
    droppedValueCount: Int,
    collapsedDuplicateCount: Int
  ) {
    self.series = series
    self.annotations = annotations
    self.droppedValueCount = droppedValueCount
    self.collapsedDuplicateCount = collapsedDuplicateCount
  }
}

public enum PlotGeometryBuilder {
  public static func makeGeometry(
    scene: PlotScene,
    layout: PlotLayout,
    options: PlotGeometryOptions = .default
  ) -> PlotGeometryResult {
    let targetCount = max(2, Int(ceil(layout.transform.plotRect.width * options.samplesPerPixel)))
    var droppedValueCount = 0
    var collapsedDuplicateCount = 0
    var resolved: [PlotResolvedSeriesGeometry] = []

    for series in scene.series {
      let normalization = PlotDataNormalizer.normalize(series, options: options.normalization)
      droppedValueCount += normalization.droppedValueCount
      collapsedDuplicateCount += normalization.collapsedDuplicateCount
      let normalized = normalization.series
      let shape: PlotSeriesShape

      switch normalized.data {
      case .line(let samples):
        shape = .line(
          lineGeometry(
            samples: samples,
            transform: layout.transform,
            targetCount: targetCount
          ))

      case .area(let samples, let baseline):
        shape = .area(
          areaGeometry(
            samples: samples,
            baseline: baseline,
            transform: layout.transform,
            targetCount: targetCount
          ))

      case .candles(let candles):
        shape = .candles(candleGeometry(candles: candles, transform: layout.transform))
      }

      resolved.append(
        PlotResolvedSeriesGeometry(
          id: normalized.id,
          name: normalized.name,
          opacity: normalized.opacity,
          shape: shape
        ))
    }

    return PlotGeometryResult(
      series: resolved,
      annotations: annotationGeometry(scene.annotations, transform: layout.transform),
      droppedValueCount: droppedValueCount,
      collapsedDuplicateCount: collapsedDuplicateCount
    )
  }

  private static func lineGeometry(
    samples: [PlotSample],
    transform: PlotTransform,
    targetCount: Int
  ) -> PlotLineGeometry {
    let sourceSegments = PlotDataNormalizer.finiteSegments(samples)
    let totalCount = max(1, sourceSegments.reduce(0) { $0 + $1.count })
    var result: [[PlotCoordinate]] = []

    for segment in sourceSegments {
      let proportionalTarget = max(
        2, Int(round(Double(targetCount) * Double(segment.count) / Double(totalCount))))
      let downsampled = PlotDownsampler.extremaPreserving(segment, targetCount: proportionalTarget)
      let mapped = downsampled.compactMap { sample -> PlotCoordinate? in
        guard let y = sample.y else { return nil }
        return transform.coordinate(x: sample.x, y: y)
      }
      result.append(contentsOf: PlotClipper.clipPolyline(mapped, to: transform.plotRect))
    }
    return PlotLineGeometry(segments: result)
  }

  private static func areaGeometry(
    samples: [PlotSample],
    baseline: PlotBaseline,
    transform: PlotTransform,
    targetCount: Int
  ) -> PlotAreaGeometry {
    let line = lineGeometry(samples: samples, transform: transform, targetCount: targetCount)
    let baselineValue: Double
    switch baseline {
    case .zero: baselineValue = 0
    case .value(let value):
      baselineValue = value.isFinite ? value : transform.yScale.domain.lowerBound
    case .lowerDomainBound: baselineValue = transform.yScale.domain.lowerBound
    }
    let baselineY = transform.yScale.position(for: baselineValue)
    let sourceSegments = PlotDataNormalizer.finiteSegments(samples)
    let totalCount = max(1, sourceSegments.reduce(0) { $0 + $1.count })
    let mappedSegments = sourceSegments.map { segment in
      let proportionalTarget = max(
        2,
        Int(round(Double(targetCount) * Double(segment.count) / Double(totalCount)))
      )
      return PlotDownsampler.extremaPreserving(segment, targetCount: proportionalTarget).compactMap
      {
        sample -> PlotCoordinate? in
        guard let y = sample.y else { return nil }
        return transform.coordinate(x: sample.x, y: y)
      }
    }
    let polygons = mappedSegments.compactMap { segment -> [PlotCoordinate]? in
      guard let first = segment.first, let last = segment.last else { return nil }
      let polygon =
        [PlotCoordinate(x: first.x, y: baselineY)]
        + segment
        + [PlotCoordinate(x: last.x, y: baselineY)]
      let clipped = PlotClipper.clipPolygon(polygon, to: transform.plotRect)
      return clipped.count >= 3 ? clipped : nil
    }
    return PlotAreaGeometry(polygons: polygons, line: line)
  }

  private static func candleGeometry(
    candles: [PlotCandle],
    transform: PlotTransform
  ) -> [PlotCandleGeometry] {
    let visible = candles.filter { transform.xScale.domain.contains($0.x) }
    let width = max(2, min(12, transform.plotRect.width / Double(max(1, visible.count)) * 0.65))

    return visible.compactMap { candle in
      guard let high = transform.coordinate(x: candle.x, y: candle.high),
        let low = transform.coordinate(x: candle.x, y: candle.low),
        let open = transform.coordinate(x: candle.x, y: candle.open),
        let close = transform.coordinate(x: candle.x, y: candle.close)
      else {
        return nil
      }
      return PlotCandleGeometry(
        x: high.x,
        highY: clamped(high.y, to: transform.plotRect.minY...transform.plotRect.maxY),
        lowY: clamped(low.y, to: transform.plotRect.minY...transform.plotRect.maxY),
        openY: clamped(open.y, to: transform.plotRect.minY...transform.plotRect.maxY),
        closeY: clamped(close.y, to: transform.plotRect.minY...transform.plotRect.maxY),
        bodyWidth: width,
        isRising: candle.close >= candle.open
      )
    }
  }

  private static func annotationGeometry(
    _ annotations: [PlotAnnotation],
    transform: PlotTransform
  ) -> [PlotAnnotationGeometry] {
    annotations.compactMap { annotation in
      switch annotation {
      case .xRange(let id, let lower, let upper, let label):
        guard lower.isFinite, upper.isFinite else { return nil }
        let first = transform.xScale.position(for: lower)
        let second = transform.xScale.position(for: upper)
        let minX = clamped(
          min(first, second), to: transform.plotRect.minX...transform.plotRect.maxX)
        let maxX = clamped(
          max(first, second), to: transform.plotRect.minX...transform.plotRect.maxX)
        guard maxX > minX else { return nil }
        return .xRange(id: id, minX: minX, maxX: maxX, label: label)

      case .xMarker(let id, let value, let label):
        guard transform.xScale.domain.contains(value) else { return nil }
        return .xMarker(id: id, x: transform.xScale.position(for: value), label: label)
      }
    }
  }

  private static func clamped(_ value: Double, to range: ClosedRange<Double>) -> Double {
    min(range.upperBound, max(range.lowerBound, value))
  }
}
