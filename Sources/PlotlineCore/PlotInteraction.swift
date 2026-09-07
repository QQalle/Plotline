import Foundation

public enum PlotSelectionMode: Sendable, Hashable {
  case nearest
  case interpolated
}

public enum PlotSelectionSource: Sendable, Hashable {
  case exact
  case nearest
  case interpolated
  case candleClose
}

public struct PlotSelectedValue: Identifiable, Sendable, Hashable {
  public var id: String { seriesID }
  public let seriesID: String
  public let seriesName: String
  public let x: Double
  public let y: Double
  public let coordinate: PlotCoordinate
  public let source: PlotSelectionSource

  public init(
    seriesID: String,
    seriesName: String,
    x: Double,
    y: Double,
    coordinate: PlotCoordinate,
    source: PlotSelectionSource
  ) {
    self.seriesID = seriesID
    self.seriesName = seriesName
    self.x = x
    self.y = y
    self.coordinate = coordinate
    self.source = source
  }
}

public struct PlotSelection: Sendable, Hashable {
  public let x: Double
  public let coordinateX: Double
  public let values: [PlotSelectedValue]
  public let annotationIDs: [String]

  public init(
    x: Double,
    coordinateX: Double,
    values: [PlotSelectedValue],
    annotationIDs: [String] = []
  ) {
    self.x = x
    self.coordinateX = coordinateX
    self.values = values
    self.annotationIDs = annotationIDs
  }
}

public struct PlotHitTestOptions: Sendable, Hashable {
  public var selectionMode: PlotSelectionMode
  public var annotationTolerance: Double
  public var normalization: PlotNormalizationOptions

  public init(
    selectionMode: PlotSelectionMode = .nearest,
    annotationTolerance: Double = 8,
    normalization: PlotNormalizationOptions = .default
  ) {
    self.selectionMode = selectionMode
    self.annotationTolerance = annotationTolerance.isFinite ? max(0, annotationTolerance) : 8
    self.normalization = normalization
  }
}

public enum PlotHitTester {
  public static func selection(
    at coordinate: PlotCoordinate,
    scene: PlotScene,
    layout: PlotLayout,
    options: PlotHitTestOptions = PlotHitTestOptions()
  ) -> PlotSelection? {
    let normalized = scene.series.map {
      PlotDataNormalizer.normalize($0, options: options.normalization).series
    }
    let pointerX = min(
      layout.transform.plotRect.maxX,
      max(layout.transform.plotRect.minX, coordinate.x)
    )
    let requestedX = layout.transform.xScale.value(at: pointerX, clamped: true)
    let selectionX: Double

    switch options.selectionMode {
    case .nearest:
      guard
        let nearest = nearestX(
          to: pointerX,
          series: normalized,
          transform: layout.transform
        )
      else { return nil }
      selectionX = nearest
    case .interpolated:
      selectionX = requestedX
    }

    let values = normalized.compactMap {
      selectedValue(
        in: $0,
        atX: selectionX,
        mode: options.selectionMode,
        transform: layout.transform
      )
    }
    guard !values.isEmpty else { return nil }

    let coordinateX = layout.transform.xScale.position(for: selectionX)
    return PlotSelection(
      x: selectionX,
      coordinateX: coordinateX,
      values: values,
      annotationIDs: matchingAnnotationIDs(
        atX: selectionX,
        coordinateX: coordinateX,
        annotations: scene.annotations,
        transform: layout.transform,
        tolerance: options.annotationTolerance
      )
    )
  }

  public static func selectableXValues(
    scene: PlotScene,
    layout: PlotLayout,
    normalization: PlotNormalizationOptions = .default
  ) -> [Double] {
    let domain = layout.transform.xScale.domain
    let values = scene.series.flatMap { series -> [Double] in
      let normalized = PlotDataNormalizer.normalize(series, options: normalization).series
      switch normalized.data {
      case .line(let samples), .area(let samples, _):
        return samples.compactMap { sample in
          sample.isFinitePoint && domain.contains(sample.x) ? sample.x : nil
        }
      case .candles(let candles):
        return candles.compactMap { domain.contains($0.x) ? $0.x : nil }
      }
    }
    return Array(Set(values)).sorted()
  }

  public static func selection(
    atX x: Double,
    scene: PlotScene,
    layout: PlotLayout,
    options: PlotHitTestOptions = PlotHitTestOptions()
  ) -> PlotSelection? {
    let coordinate = PlotCoordinate(
      x: layout.transform.xScale.position(for: x, clamped: true),
      y: layout.transform.plotRect.minY
    )
    return selection(at: coordinate, scene: scene, layout: layout, options: options)
  }

  private static func nearestX(
    to coordinateX: Double,
    series: [PlotSeries],
    transform: PlotTransform
  ) -> Double? {
    let domain = transform.xScale.domain
    var best: (x: Double, distance: Double)?

    for series in series {
      let values: [Double]
      switch series.data {
      case .line(let samples), .area(let samples, _):
        values = samples.compactMap {
          $0.isFinitePoint && domain.contains($0.x) ? $0.x : nil
        }
      case .candles(let candles):
        values = candles.compactMap { domain.contains($0.x) ? $0.x : nil }
      }

      for x in values {
        let distance = abs(transform.xScale.position(for: x) - coordinateX)
        if best == nil || distance < best!.distance {
          best = (x, distance)
        }
      }
    }
    return best?.x
  }

  private static func selectedValue(
    in series: PlotSeries,
    atX x: Double,
    mode: PlotSelectionMode,
    transform: PlotTransform
  ) -> PlotSelectedValue? {
    switch series.data {
    case .line(let samples), .area(let samples, _):
      let point: (x: Double, y: Double, source: PlotSelectionSource)?
      switch mode {
      case .nearest:
        point = nearestSample(to: x, samples: samples, domain: transform.xScale.domain).map {
          ($0.x, $0.y!, $0.x == x ? .exact : .nearest)
        }
      case .interpolated:
        point = interpolatedSample(atX: x, samples: samples)
      }
      guard let point, let coordinate = transform.coordinate(x: point.x, y: point.y) else {
        return nil
      }
      return PlotSelectedValue(
        seriesID: series.id,
        seriesName: series.name,
        x: point.x,
        y: point.y,
        coordinate: coordinate,
        source: point.source
      )

    case .candles(let candles):
      guard
        let candle = candles.filter({ transform.xScale.domain.contains($0.x) })
          .min(by: { abs($0.x - x) < abs($1.x - x) }),
        let coordinate = transform.coordinate(x: candle.x, y: candle.close)
      else { return nil }
      return PlotSelectedValue(
        seriesID: series.id,
        seriesName: series.name,
        x: candle.x,
        y: candle.close,
        coordinate: coordinate,
        source: .candleClose
      )
    }
  }

  private static func nearestSample(
    to x: Double,
    samples: [PlotSample],
    domain: PlotDomain
  ) -> PlotSample? {
    samples.compactMap { $0.isFinitePoint && domain.contains($0.x) ? $0 : nil }
      .min { abs($0.x - x) < abs($1.x - x) }
  }

  private static func interpolatedSample(
    atX x: Double,
    samples: [PlotSample]
  ) -> (x: Double, y: Double, source: PlotSelectionSource)? {
    for segment in PlotDataNormalizer.finiteSegments(samples) {
      if let exact = segment.first(where: { $0.x == x }), let y = exact.y {
        return (x, y, .exact)
      }
      for (lower, upper) in zip(segment, segment.dropFirst())
      where lower.x <= x && x <= upper.x {
        guard let lowerY = lower.y, let upperY = upper.y else { continue }
        let span = upper.x - lower.x
        guard span > 0 else { return (x, upperY, .exact) }
        let fraction = (x - lower.x) / span
        return (x, lowerY + fraction * (upperY - lowerY), .interpolated)
      }
    }
    return nil
  }

  private static func matchingAnnotationIDs(
    atX x: Double,
    coordinateX: Double,
    annotations: [PlotAnnotation],
    transform: PlotTransform,
    tolerance: Double
  ) -> [String] {
    annotations.compactMap { annotation in
      switch annotation {
      case .xRange(let id, let lower, let upper, _):
        return min(lower, upper) <= x && x <= max(lower, upper) ? id : nil
      case .xMarker(let id, let value, _):
        guard value.isFinite else { return nil }
        return abs(transform.xScale.position(for: value) - coordinateX) <= tolerance ? id : nil
      }
    }
  }
}
