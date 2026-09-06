import Foundation

public struct PlotSize: Sendable, Hashable {
  public var width: Double
  public var height: Double

  public init(width: Double, height: Double) {
    self.width = width.isFinite ? max(0, width) : 0
    self.height = height.isFinite ? max(0, height) : 0
  }
}

public struct PlotInsets: Sendable, Hashable {
  public var top: Double
  public var leading: Double
  public var bottom: Double
  public var trailing: Double

  public init(top: Double, leading: Double, bottom: Double, trailing: Double) {
    self.top = finiteNonnegative(top)
    self.leading = finiteNonnegative(leading)
    self.bottom = finiteNonnegative(bottom)
    self.trailing = finiteNonnegative(trailing)
  }
}

public struct PlotRect: Sendable, Hashable {
  public var minX: Double
  public var minY: Double
  public var width: Double
  public var height: Double

  public init(minX: Double, minY: Double, width: Double, height: Double) {
    self.minX = minX.isFinite ? minX : 0
    self.minY = minY.isFinite ? minY : 0
    self.width = finiteNonnegative(width)
    self.height = finiteNonnegative(height)
  }

  public var maxX: Double { minX + width }
  public var maxY: Double { minY + height }

  public func contains(_ point: PlotCoordinate) -> Bool {
    point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
  }
}

public struct PlotCoordinate: Sendable, Hashable {
  public var x: Double
  public var y: Double

  public init(x: Double, y: Double) {
    self.x = x
    self.y = y
  }
}

public struct PlotDataValue: Sendable, Hashable {
  public var x: Double
  public var y: Double

  public init(x: Double, y: Double) {
    self.x = x
    self.y = y
  }
}

public struct PlotLayoutMetrics: Sendable, Hashable {
  public var maximumYAxisLabelWidth: Double
  public var maximumYAxisLabelHeight: Double
  public var maximumXAxisLabelHeight: Double
  public var maximumXAxisLabelWidth: Double
  public var xAxisTitleHeight: Double
  public var yAxisTitleHeight: Double
  public var outerPadding: Double
  public var labelSpacing: Double

  public init(
    maximumYAxisLabelWidth: Double = 32,
    maximumYAxisLabelHeight: Double = 11,
    maximumXAxisLabelHeight: Double = 11,
    maximumXAxisLabelWidth: Double = 28,
    xAxisTitleHeight: Double = 0,
    yAxisTitleHeight: Double = 0,
    outerPadding: Double = 10,
    labelSpacing: Double = 6
  ) {
    self.maximumYAxisLabelWidth = finiteNonnegative(maximumYAxisLabelWidth)
    self.maximumYAxisLabelHeight = finiteNonnegative(maximumYAxisLabelHeight)
    self.maximumXAxisLabelHeight = finiteNonnegative(maximumXAxisLabelHeight)
    self.maximumXAxisLabelWidth = finiteNonnegative(maximumXAxisLabelWidth)
    self.xAxisTitleHeight = finiteNonnegative(xAxisTitleHeight)
    self.yAxisTitleHeight = finiteNonnegative(yAxisTitleHeight)
    self.outerPadding = finiteNonnegative(outerPadding)
    self.labelSpacing = finiteNonnegative(labelSpacing)
  }

  public func insets() -> PlotInsets {
    PlotInsets(
      top: outerPadding + yAxisTitleHeight + (yAxisTitleHeight > 0 ? labelSpacing : 0),
      leading: outerPadding + maximumYAxisLabelWidth + labelSpacing,
      bottom: outerPadding + maximumXAxisLabelHeight + xAxisTitleHeight + labelSpacing,
      trailing: outerPadding
    )
  }
}

private func finiteNonnegative(_ value: Double) -> Double {
  value.isFinite ? max(0, value) : 0
}

public struct PlotTransform: Sendable, Hashable {
  public let plotRect: PlotRect
  public let xScale: PlotScale
  public let yScale: PlotScale

  public init(plotRect: PlotRect, xScale: PlotScale, yScale: PlotScale) {
    self.plotRect = plotRect
    self.xScale = xScale
    self.yScale = yScale
  }

  public func coordinate(x: Double, y: Double) -> PlotCoordinate? {
    guard x.isFinite, y.isFinite else { return nil }
    return PlotCoordinate(x: xScale.position(for: x), y: yScale.position(for: y))
  }

  public func dataValue(at coordinate: PlotCoordinate, clamped: Bool = false) -> PlotDataValue {
    PlotDataValue(
      x: xScale.value(at: coordinate.x, clamped: clamped),
      y: yScale.value(at: coordinate.y, clamped: clamped)
    )
  }
}

public struct PlotLayout: Sendable, Hashable {
  public let size: PlotSize
  public let insets: PlotInsets
  public let transform: PlotTransform
  public let xTicks: [PlotTick]
  public let yTicks: [PlotTick]

  public init(
    size: PlotSize,
    insets: PlotInsets,
    transform: PlotTransform,
    xTicks: [PlotTick],
    yTicks: [PlotTick]
  ) {
    self.size = size
    self.insets = insets
    self.transform = transform
    self.xTicks = xTicks
    self.yTicks = yTicks
  }
}

public enum PlotLayoutEngine {
  public static func makeLayout(
    scene: PlotScene,
    size: PlotSize,
    metrics: PlotLayoutMetrics = PlotLayoutMetrics()
  ) -> PlotLayout? {
    guard let xDomain = scene.resolvedXDomain, let yDomain = scene.resolvedYDomain else {
      return nil
    }

    let insets = metrics.insets()
    let plotRect = PlotRect(
      minX: insets.leading,
      minY: insets.top,
      width: size.width - insets.leading - insets.trailing,
      height: size.height - insets.top - insets.bottom
    )
    guard plotRect.width > 0, plotRect.height > 0 else { return nil }

    let xScale = PlotScale(
      domain: xDomain,
      range: plotRect.minX...plotRect.maxX,
      direction: scene.xAxis.direction
    )
    let screenYDirection: PlotAxisDirection = scene.yAxis.direction == .normal ? .reversed : .normal
    let yScale = PlotScale(
      domain: yDomain,
      range: plotRect.minY...plotRect.maxY,
      direction: screenYDirection
    )
    let rawXTicks = PlotTickGenerator.ticks(for: xDomain, axis: scene.xAxis)
    let rawYTicks = PlotTickGenerator.ticks(for: yDomain, axis: scene.yAxis)
    let maximumXTicks = max(
      2, Int(floor(plotRect.width / max(1, metrics.maximumXAxisLabelWidth + metrics.labelSpacing))))
    let maximumYTicks = max(
      2,
      Int(floor(plotRect.height / max(1, metrics.maximumYAxisLabelHeight + metrics.labelSpacing))))

    return PlotLayout(
      size: size,
      insets: insets,
      transform: PlotTransform(plotRect: plotRect, xScale: xScale, yScale: yScale),
      xTicks: thinned(rawXTicks, maximumCount: maximumXTicks),
      yTicks: thinned(rawYTicks, maximumCount: maximumYTicks)
    )
  }

  private static func thinned(_ ticks: [PlotTick], maximumCount: Int) -> [PlotTick] {
    guard ticks.count > maximumCount, maximumCount >= 2 else { return ticks }
    let lastIndex = ticks.count - 1
    var selected: [PlotTick] = []
    var usedIndices: Set<Int> = []

    for slot in 0..<maximumCount {
      let index = Int(round(Double(slot) * Double(lastIndex) / Double(maximumCount - 1)))
      if usedIndices.insert(index).inserted { selected.append(ticks[index]) }
    }
    return selected
  }
}
