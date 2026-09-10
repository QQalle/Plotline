import SwiftUI

public struct PlotlineLiveIndicatorStyle: Sendable, Hashable {
  public var dotRadius: Double
  public var glowRadius: Double
  public var glowOpacity: Double
  public var pulseDuration: TimeInterval

  public init(
    dotRadius: Double = 4,
    glowRadius: Double = 12,
    glowOpacity: Double = 0.18,
    pulseDuration: TimeInterval = 1.4
  ) {
    self.dotRadius = dotRadius.isFinite ? max(1, dotRadius) : 4
    self.glowRadius = glowRadius.isFinite ? max(self.dotRadius, glowRadius) : 12
    self.glowOpacity = glowOpacity.isFinite ? max(0, min(1, glowOpacity)) : 0.18
    self.pulseDuration = pulseDuration.isFinite ? max(0.2, pulseDuration) : 1.4
  }

  public static let standard = PlotlineLiveIndicatorStyle()
}

@MainActor
public struct PlotlineStyle {
  public var background: Color
  public var grid: Color
  public var axis: Color
  public var annotation: Color
  public var crosshair: Color
  public var palette: [Color]
  public var risingCandle: Color
  public var fallingCandle: Color
  public var lineWidth: Double
  public var pointRadius: Double
  public var selectionPointRadius: Double
  public var crosshairLineWidth: Double
  public var areaOpacity: Double
  public var liveIndicator: PlotlineLiveIndicatorStyle

  public init(
    background: Color = Color(.sRGB, white: 0.98, opacity: 1),
    grid: Color = Color.primary.opacity(0.1),
    axis: Color = Color.secondary,
    annotation: Color = Color.accentColor,
    crosshair: Color = Color.primary.opacity(0.65),
    palette: [Color] = [.green, .blue, .orange, .purple, .pink],
    risingCandle: Color = .green,
    fallingCandle: Color = .red,
    lineWidth: Double = 2.5,
    pointRadius: Double = 3,
    selectionPointRadius: Double = 4,
    crosshairLineWidth: Double = 1,
    areaOpacity: Double = 0.2,
    liveIndicator: PlotlineLiveIndicatorStyle = .standard
  ) {
    self.background = background
    self.grid = grid
    self.axis = axis
    self.annotation = annotation
    self.crosshair = crosshair
    self.palette = palette.isEmpty ? [.primary] : palette
    self.risingCandle = risingCandle
    self.fallingCandle = fallingCandle
    self.lineWidth = max(0.5, lineWidth)
    self.pointRadius = max(1, pointRadius)
    self.selectionPointRadius = max(1, selectionPointRadius)
    self.crosshairLineWidth = max(0.5, crosshairLineWidth)
    self.areaOpacity = max(0, min(1, areaOpacity))
    self.liveIndicator = liveIndicator
  }

  public static let standard = PlotlineStyle()
}
