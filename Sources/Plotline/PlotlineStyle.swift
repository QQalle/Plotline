import SwiftUI

public struct PlotlineGridVisibility: OptionSet, Sendable, Hashable {
  public let rawValue: UInt8

  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  public static let horizontal = PlotlineGridVisibility(rawValue: 1 << 0)
  public static let vertical = PlotlineGridVisibility(rawValue: 1 << 1)
  public static let border = PlotlineGridVisibility(rawValue: 1 << 2)
  public static let all: PlotlineGridVisibility = [.horizontal, .vertical, .border]
  public static let none: PlotlineGridVisibility = []
}

public enum PlotlineYAxisPosition: Sendable, Hashable {
  case leading
  case trailing
}

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
  public var zoneColors: [String: Color]
  public var risingCandle: Color
  public var fallingCandle: Color
  public var lineWidth: Double
  public var pointRadius: Double
  public var selectionPointRadius: Double
  public var crosshairLineWidth: Double
  public var areaOpacity: Double
  public var gridVisibility: PlotlineGridVisibility
  public var yAxisPosition: PlotlineYAxisPosition
  public var showsXAxisLabels: Bool
  public var showsYAxisLabels: Bool
  public var showsAxisTitles: Bool
  public var showsZoneBoundaryLabels: Bool
  public var zoneBoundaryLineWidth: Double
  public var zoneBoundaryDash: [CGFloat]
  public var zoneBoundaryOpacity: Double
  public var liveIndicator: PlotlineLiveIndicatorStyle

  public init(
    background: Color = Color(.sRGB, white: 0.98, opacity: 1),
    grid: Color = Color.primary.opacity(0.1),
    axis: Color = Color.secondary,
    annotation: Color = Color.accentColor,
    crosshair: Color = Color.primary.opacity(0.65),
    palette: [Color] = [.green, .blue, .orange, .purple, .pink],
    zoneColors: [String: Color] = [:],
    risingCandle: Color = .green,
    fallingCandle: Color = .red,
    lineWidth: Double = 2.5,
    pointRadius: Double = 3,
    selectionPointRadius: Double = 4,
    crosshairLineWidth: Double = 1,
    areaOpacity: Double = 0.2,
    gridVisibility: PlotlineGridVisibility = .all,
    yAxisPosition: PlotlineYAxisPosition = .leading,
    showsXAxisLabels: Bool = true,
    showsYAxisLabels: Bool = true,
    showsAxisTitles: Bool = true,
    showsZoneBoundaryLabels: Bool = false,
    zoneBoundaryLineWidth: Double = 1.5,
    zoneBoundaryDash: [CGFloat] = [1, 5],
    zoneBoundaryOpacity: Double = 0.8,
    liveIndicator: PlotlineLiveIndicatorStyle = .standard
  ) {
    self.background = background
    self.grid = grid
    self.axis = axis
    self.annotation = annotation
    self.crosshair = crosshair
    self.palette = palette.isEmpty ? [.primary] : palette
    self.zoneColors = zoneColors
    self.risingCandle = risingCandle
    self.fallingCandle = fallingCandle
    self.lineWidth = max(0.5, lineWidth)
    self.pointRadius = max(1, pointRadius)
    self.selectionPointRadius = max(1, selectionPointRadius)
    self.crosshairLineWidth = max(0.5, crosshairLineWidth)
    self.areaOpacity = max(0, min(1, areaOpacity))
    self.gridVisibility = gridVisibility
    self.yAxisPosition = yAxisPosition
    self.showsXAxisLabels = showsXAxisLabels
    self.showsYAxisLabels = showsYAxisLabels
    self.showsAxisTitles = showsAxisTitles
    self.showsZoneBoundaryLabels = showsZoneBoundaryLabels
    self.zoneBoundaryLineWidth = max(0.5, zoneBoundaryLineWidth)
    self.zoneBoundaryDash = zoneBoundaryDash.filter { $0.isFinite && $0 >= 0 }
    self.zoneBoundaryOpacity = max(0, min(1, zoneBoundaryOpacity))
    self.liveIndicator = liveIndicator
  }

  public static let standard = PlotlineStyle()
}
