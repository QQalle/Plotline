import PlotlineCore
import SwiftUI

public struct PlotlineView: View {
    private let scene: PlotScene
    private let style: PlotlineStyle

    public init(scene: PlotScene, style: PlotlineStyle = .standard) {
        self.scene = scene
        self.style = style
    }

    public var body: some View {
        Canvas { context, size in
            draw(context: &context, size: size)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(scene.accessibilityLabel)
    }

    private func draw(context: inout GraphicsContext, size: CGSize) {
        let bounds = CGRect(origin: .zero, size: size)
        context.fill(Path(bounds), with: .color(style.background))

        guard size.width > 80, size.height > 70,
              let xDomain = scene.xAxis.domain ?? scene.automaticXDomain,
              let yDomain = scene.yAxis.domain ?? scene.automaticYDomain else {
            drawEmptyState(context: &context, bounds: bounds)
            return
        }

        let plot = bounds.inset(by: EdgeInsets(top: 12, leading: 42, bottom: 30, trailing: 12))
        let xScale = PlotScale(
            domain: xDomain,
            range: plot.minX...plot.maxX,
            direction: scene.xAxis.direction
        )
        let yDirection: PlotAxisDirection = scene.yAxis.direction == .normal ? .reversed : .normal
        let yScale = PlotScale(
            domain: yDomain,
            range: plot.minY...plot.maxY,
            direction: yDirection
        )

        drawGrid(context: &context, plot: plot, xScale: xScale, yScale: yScale)

        var clipped = context
        clipped.clip(to: Path(plot))
        drawAnnotations(context: &clipped, plot: plot, xScale: xScale)
        drawSeries(context: &clipped, plot: plot, xScale: xScale, yScale: yScale)

        drawLabels(context: &context, plot: plot, xScale: xScale, yScale: yScale)
    }

    private func drawGrid(
        context: inout GraphicsContext,
        plot: CGRect,
        xScale: PlotScale,
        yScale: PlotScale
    ) {
        for index in 0...4 {
            let fraction = Double(index) / 4
            let x = plot.minX + plot.width * fraction
            let y = plot.minY + plot.height * fraction

            var vertical = Path()
            vertical.move(to: CGPoint(x: x, y: plot.minY))
            vertical.addLine(to: CGPoint(x: x, y: plot.maxY))
            context.stroke(vertical, with: .color(style.grid), lineWidth: 1)

            var horizontal = Path()
            horizontal.move(to: CGPoint(x: plot.minX, y: y))
            horizontal.addLine(to: CGPoint(x: plot.maxX, y: y))
            context.stroke(horizontal, with: .color(style.grid), lineWidth: 1)
        }

        context.stroke(Path(plot), with: .color(style.grid), lineWidth: 1)
    }

    private func drawAnnotations(context: inout GraphicsContext, plot: CGRect, xScale: PlotScale) {
        for annotation in scene.annotations {
            switch annotation {
            case .xRange(_, let lower, let upper, _):
                let x1 = xScale.position(for: lower)
                let x2 = xScale.position(for: upper)
                let rect = CGRect(
                    x: min(x1, x2),
                    y: plot.minY,
                    width: abs(x2 - x1),
                    height: plot.height
                )
                context.fill(Path(rect), with: .color(style.annotation.opacity(0.12)))

            case .xMarker(_, let value, _):
                let x = xScale.position(for: value)
                var path = Path()
                path.move(to: CGPoint(x: x, y: plot.minY))
                path.addLine(to: CGPoint(x: x, y: plot.maxY))
                context.stroke(path, with: .color(style.annotation), lineWidth: 1)
            }
        }
    }

    private func drawSeries(
        context: inout GraphicsContext,
        plot: CGRect,
        xScale: PlotScale,
        yScale: PlotScale
    ) {
        for (index, series) in scene.series.enumerated() {
            let color = style.palette[index % style.palette.count].opacity(series.opacity)
            switch series.data {
            case .line(let samples):
                drawLine(samples, context: &context, xScale: xScale, yScale: yScale, color: color)
            case .area(let samples, let baseline):
                drawArea(
                    samples,
                    baseline: baseline,
                    context: &context,
                    xScale: xScale,
                    yScale: yScale,
                    color: color
                )
            case .candles(let candles):
                drawCandles(
                    candles,
                    context: &context,
                    plot: plot,
                    xScale: xScale,
                    yScale: yScale,
                    opacity: series.opacity
                )
            }
        }
    }

    private func drawLine(
        _ samples: [PlotSample],
        context: inout GraphicsContext,
        xScale: PlotScale,
        yScale: PlotScale,
        color: Color
    ) {
        for segment in finiteSegments(samples) {
            var path = Path()
            for (index, sample) in segment.enumerated() {
                let point = CGPoint(x: xScale.position(for: sample.x), y: yScale.position(for: sample.y!))
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(lineWidth: style.lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
    }

    private func drawArea(
        _ samples: [PlotSample],
        baseline: PlotBaseline,
        context: inout GraphicsContext,
        xScale: PlotScale,
        yScale: PlotScale,
        color: Color
    ) {
        let baselineValue: Double
        switch baseline {
        case .zero: baselineValue = 0
        case .value(let value): baselineValue = value
        case .lowerDomainBound: baselineValue = yScale.domain.lowerBound
        }
        let baselineY = yScale.position(for: baselineValue)

        for segment in finiteSegments(samples) where !segment.isEmpty {
            var fill = Path()
            fill.move(to: CGPoint(x: xScale.position(for: segment[0].x), y: baselineY))
            for sample in segment {
                fill.addLine(to: CGPoint(x: xScale.position(for: sample.x), y: yScale.position(for: sample.y!)))
            }
            fill.addLine(to: CGPoint(x: xScale.position(for: segment[segment.count - 1].x), y: baselineY))
            fill.closeSubpath()
            context.fill(fill, with: .color(color.opacity(style.areaOpacity)))
        }

        drawLine(samples, context: &context, xScale: xScale, yScale: yScale, color: color)
    }

    private func drawCandles(
        _ candles: [PlotCandle],
        context: inout GraphicsContext,
        plot: CGRect,
        xScale: PlotScale,
        yScale: PlotScale,
        opacity: Double
    ) {
        let finite = candles.filter {
            $0.x.isFinite && $0.open.isFinite && $0.high.isFinite && $0.low.isFinite && $0.close.isFinite
        }
        let candleWidth = max(2, min(12, plot.width / Double(max(1, finite.count)) * 0.65))

        for candle in finite {
            let x = xScale.position(for: candle.x)
            let isRising = candle.close >= candle.open
            let candleColor = (isRising ? style.risingCandle : style.fallingCandle)
                .opacity(opacity)

            var wick = Path()
            wick.move(to: CGPoint(x: x, y: yScale.position(for: candle.high)))
            wick.addLine(to: CGPoint(x: x, y: yScale.position(for: candle.low)))
            context.stroke(wick, with: .color(candleColor), lineWidth: 1)

            let openY = yScale.position(for: candle.open)
            let closeY = yScale.position(for: candle.close)
            let body = CGRect(
                x: x - candleWidth / 2,
                y: min(openY, closeY),
                width: candleWidth,
                height: max(1, abs(closeY - openY))
            )
            context.fill(Path(body), with: .color(candleColor))
        }
    }

    private func drawLabels(
        context: inout GraphicsContext,
        plot: CGRect,
        xScale: PlotScale,
        yScale: PlotScale
    ) {
        for index in 0...4 {
            let fraction = Double(index) / 4
            let x = plot.minX + plot.width * fraction
            let y = plot.maxY - plot.height * fraction
            let xValue = xScale.value(at: x)
            let yValue = yScale.value(at: y)

            context.draw(
                Text(scene.xAxis.formatter(xValue)).font(.system(size: 9, design: .monospaced)).foregroundStyle(style.axis),
                at: CGPoint(x: x, y: plot.maxY + 10),
                anchor: .top
            )
            context.draw(
                Text(scene.yAxis.formatter(yValue)).font(.system(size: 9, design: .monospaced)).foregroundStyle(style.axis),
                at: CGPoint(x: plot.minX - 5, y: y),
                anchor: .trailing
            )
        }
    }

    private func drawEmptyState(context: inout GraphicsContext, bounds: CGRect) {
        context.draw(
            Text("No graph data").font(.caption).foregroundStyle(style.axis),
            at: CGPoint(x: bounds.midX, y: bounds.midY),
            anchor: .center
        )
    }

    private func finiteSegments(_ samples: [PlotSample]) -> [[PlotSample]] {
        var result: [[PlotSample]] = []
        var current: [PlotSample] = []

        for sample in samples {
            if sample.x.isFinite, let y = sample.y, y.isFinite {
                current.append(sample)
            } else if !current.isEmpty {
                result.append(current)
                current = []
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

}

private extension CGRect {
    func inset(by insets: EdgeInsets) -> CGRect {
        CGRect(
            x: minX + insets.leading,
            y: minY + insets.top,
            width: max(0, width - insets.leading - insets.trailing),
            height: max(0, height - insets.top - insets.bottom)
        )
    }
}
