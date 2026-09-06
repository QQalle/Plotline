import SwiftUI

@MainActor
public struct PlotlineStyle {
    public var background: Color
    public var grid: Color
    public var axis: Color
    public var annotation: Color
    public var palette: [Color]
    public var risingCandle: Color
    public var fallingCandle: Color
    public var lineWidth: Double
    public var areaOpacity: Double

    public init(
        background: Color = Color(.sRGB, white: 0.98, opacity: 1),
        grid: Color = Color.primary.opacity(0.1),
        axis: Color = Color.secondary,
        annotation: Color = Color.accentColor,
        palette: [Color] = [.green, .blue, .orange, .purple, .pink],
        risingCandle: Color = .green,
        fallingCandle: Color = .red,
        lineWidth: Double = 2.5,
        areaOpacity: Double = 0.2
    ) {
        self.background = background
        self.grid = grid
        self.axis = axis
        self.annotation = annotation
        self.palette = palette.isEmpty ? [.primary] : palette
        self.risingCandle = risingCandle
        self.fallingCandle = fallingCandle
        self.lineWidth = max(0.5, lineWidth)
        self.areaOpacity = max(0, min(1, areaOpacity))
    }

    public static let standard = PlotlineStyle()
}
