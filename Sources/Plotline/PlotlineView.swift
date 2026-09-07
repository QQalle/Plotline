import PlotlineCore
import SwiftUI

public struct PlotlineView: View {
  private let scene: PlotScene
  private let style: PlotlineStyle
  private let selectionBinding: Binding<PlotSelection?>?
  private let interaction: PlotlineInteractionConfiguration
  private let onSelectionChange: ((PlotSelection?) -> Void)?

  @State private var localSelection: PlotSelection?
  @State private var latestLayout: PlotLayout?

  public init(
    scene: PlotScene,
    style: PlotlineStyle = .standard,
    interaction: PlotlineInteractionConfiguration = .standard,
    onSelectionChange: ((PlotSelection?) -> Void)? = nil
  ) {
    self.scene = scene
    self.style = style
    self.selectionBinding = nil
    self.interaction = interaction
    self.onSelectionChange = onSelectionChange
    _localSelection = State(initialValue: nil)
  }

  public init(
    scene: PlotScene,
    style: PlotlineStyle = .standard,
    selection: Binding<PlotSelection?>,
    interaction: PlotlineInteractionConfiguration = .standard,
    onSelectionChange: ((PlotSelection?) -> Void)? = nil
  ) {
    self.scene = scene
    self.style = style
    self.selectionBinding = selection
    self.interaction = interaction
    self.onSelectionChange = onSelectionChange
    _localSelection = State(initialValue: nil)
  }

  public var body: some View {
    Canvas { context, size in
      draw(context: &context, size: size)
    }
    .contentShape(Rectangle())
    .simultaneousGesture(scrubbingGesture)
    .accessibilityChartDescriptor(PlotlineChartDescriptor(scene: scene))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(scene.accessibilityLabel)
    .accessibilityValue(accessibilityMetadata.selectionSummary ?? accessibilityMetadata.summary)
    .accessibilityHint(accessibilityHint)
    .accessibilityAdjustableAction { direction in
      adjustSelection(direction)
    }
  }

  private var currentSelection: PlotSelection? {
    selectionBinding?.wrappedValue ?? localSelection
  }

  private var accessibilityMetadata: PlotAccessibilityMetadata {
    PlotAccessibilityBuilder.metadata(for: scene, selection: currentSelection)
  }

  private var accessibilityHint: String {
    guard interaction.isEnabled, interaction.allowsAccessibilityAdjustment else {
      return "Use the audio graph to explore the data"
    }
    return "Swipe up or down to inspect adjacent values, or drag across the graph"
  }

  private var scrubbingGesture: some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { value in
        guard interaction.isEnabled, let layout = latestLayout else { return }
        let isVerticalScroll =
          abs(value.translation.height) > abs(value.translation.width)
          && abs(value.translation.height) > 8
        guard !isVerticalScroll else { return }
        updateSelection(at: value.location, layout: layout)
      }
      .onEnded { _ in
        if interaction.persistence == .whileInteracting {
          setSelection(nil)
        }
      }
  }

  private func draw(context: inout GraphicsContext, size: CGSize) {
    let bounds = CGRect(origin: .zero, size: size)
    context.fill(Path(bounds), with: .color(style.background))

    guard size.width > 80, size.height > 70,
      let layout = makeLayout(context: context, size: size)
    else {
      drawEmptyState(context: &context, bounds: bounds)
      return
    }

    let geometry = PlotGeometryBuilder.makeGeometry(scene: scene, layout: layout)
    cache(layout: layout)
    drawGrid(context: &context, layout: layout)

    var clipped = context
    clipped.clip(to: Path(layout.transform.plotRect.cgRect))
    drawAnnotations(geometry.annotations, context: &clipped, plot: layout.transform.plotRect)
    drawSeries(geometry.series, context: &clipped)
    drawSelection(context: &clipped, layout: layout)

    drawLabels(context: &context, layout: layout)
  }

  private func cache(layout: PlotLayout) {
    guard latestLayout != layout else { return }
    Task { @MainActor in
      latestLayout = layout
    }
  }

  private func updateSelection(at location: CGPoint, layout: PlotLayout) {
    let plot = layout.transform.plotRect
    guard location.y >= plot.minY - 16, location.y <= plot.maxY + 16 else { return }
    let selection = PlotHitTester.selection(
      at: PlotCoordinate(x: location.x, y: location.y),
      scene: scene,
      layout: layout,
      options: PlotHitTestOptions(
        selectionMode: interaction.selectionMode,
        annotationTolerance: interaction.annotationTolerance
      )
    )
    setSelection(selection)
  }

  private func setSelection(_ selection: PlotSelection?) {
    guard currentSelection != selection else { return }
    if let selectionBinding {
      selectionBinding.wrappedValue = selection
    } else {
      localSelection = selection
    }
    onSelectionChange?(selection)
  }

  private func adjustSelection(_ direction: AccessibilityAdjustmentDirection) {
    guard interaction.isEnabled, interaction.allowsAccessibilityAdjustment,
      let layout = latestLayout
    else { return }
    let xValues = PlotHitTester.selectableXValues(scene: scene, layout: layout)
    guard !xValues.isEmpty else { return }

    let currentIndex = currentSelection.flatMap { selection in
      xValues.indices.min { abs(xValues[$0] - selection.x) < abs(xValues[$1] - selection.x) }
    }
    let nextIndex: Int
    switch direction {
    case .increment:
      nextIndex = min((currentIndex ?? -1) + 1, xValues.count - 1)
    case .decrement:
      nextIndex = max((currentIndex ?? xValues.count) - 1, 0)
    @unknown default:
      return
    }
    let options = PlotHitTestOptions(
      selectionMode: .nearest,
      annotationTolerance: interaction.annotationTolerance
    )
    setSelection(
      PlotHitTester.selection(
        atX: xValues[nextIndex], scene: scene, layout: layout, options: options)
    )
  }

  private func drawSelection(context: inout GraphicsContext, layout: PlotLayout) {
    guard let selection = currentSelection else { return }
    let plot = layout.transform.plotRect
    let x = layout.transform.xScale.position(for: selection.x)
    guard x >= plot.minX, x <= plot.maxX else { return }

    var vertical = Path()
    vertical.move(to: CGPoint(x: x, y: plot.minY))
    vertical.addLine(to: CGPoint(x: x, y: plot.maxY))
    context.stroke(
      vertical,
      with: .color(style.crosshair),
      style: StrokeStyle(lineWidth: style.crosshairLineWidth, dash: [4, 3])
    )

    if let first = selection.values.first {
      let y = layout.transform.yScale.position(for: first.y)
      if y >= plot.minY, y <= plot.maxY {
        var horizontal = Path()
        horizontal.move(to: CGPoint(x: plot.minX, y: y))
        horizontal.addLine(to: CGPoint(x: plot.maxX, y: y))
        context.stroke(
          horizontal,
          with: .color(style.crosshair.opacity(0.55)),
          style: StrokeStyle(lineWidth: style.crosshairLineWidth, dash: [4, 3])
        )
      }
    }

    for (index, value) in selection.values.enumerated() {
      let coordinate = layout.transform.coordinate(x: value.x, y: value.y)
      guard let coordinate, plot.contains(coordinate) else { continue }
      let radius = style.selectionPointRadius
      let rect = CGRect(
        x: coordinate.x - radius,
        y: coordinate.y - radius,
        width: radius * 2,
        height: radius * 2
      )
      let color = style.palette[index % style.palette.count]
      context.fill(Path(ellipseIn: rect), with: .color(style.background))
      context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: 2)
    }
  }

  private func makeLayout(context: GraphicsContext, size: CGSize) -> PlotLayout? {
    guard let xDomain = scene.resolvedXDomain, let yDomain = scene.resolvedYDomain else {
      return nil
    }
    let xTicks = PlotTickGenerator.ticks(for: xDomain, axis: scene.xAxis)
    let yTicks = PlotTickGenerator.ticks(for: yDomain, axis: scene.yAxis)
    let xSizes = xTicks.map { measuredSize(of: $0.label, context: context) }
    let ySizes = yTicks.map { measuredSize(of: $0.label, context: context) }
    let titleHeight =
      scene.xAxis.label.isEmpty ? 0 : measuredSize(of: scene.xAxis.label, context: context).height
    let yTitleHeight =
      scene.yAxis.label.isEmpty ? 0 : measuredSize(of: scene.yAxis.label, context: context).height

    let metrics = PlotLayoutMetrics(
      maximumYAxisLabelWidth: Double(ySizes.map(\.width).max() ?? 0),
      maximumYAxisLabelHeight: Double(ySizes.map(\.height).max() ?? 0),
      maximumXAxisLabelHeight: Double(xSizes.map(\.height).max() ?? 0),
      maximumXAxisLabelWidth: Double(xSizes.map(\.width).max() ?? 0),
      xAxisTitleHeight: Double(titleHeight),
      yAxisTitleHeight: Double(yTitleHeight),
      outerPadding: 10,
      labelSpacing: 6
    )
    return PlotLayoutEngine.makeLayout(
      scene: scene,
      size: PlotSize(width: size.width, height: size.height),
      metrics: metrics
    )
  }

  private func drawGrid(context: inout GraphicsContext, layout: PlotLayout) {
    let plot = layout.transform.plotRect

    for tick in layout.xTicks {
      let x = layout.transform.xScale.position(for: tick.value)
      var path = Path()
      path.move(to: CGPoint(x: x, y: plot.minY))
      path.addLine(to: CGPoint(x: x, y: plot.maxY))
      context.stroke(path, with: .color(style.grid), lineWidth: 1)
    }

    for tick in layout.yTicks {
      let y = layout.transform.yScale.position(for: tick.value)
      var path = Path()
      path.move(to: CGPoint(x: plot.minX, y: y))
      path.addLine(to: CGPoint(x: plot.maxX, y: y))
      context.stroke(path, with: .color(style.grid), lineWidth: 1)
    }

    context.stroke(Path(plot.cgRect), with: .color(style.grid), lineWidth: 1)
  }

  private func drawAnnotations(
    _ annotations: [PlotAnnotationGeometry],
    context: inout GraphicsContext,
    plot: PlotRect
  ) {
    for annotation in annotations {
      switch annotation {
      case .xRange(_, let minX, let maxX, _):
        let rect = CGRect(x: minX, y: plot.minY, width: maxX - minX, height: plot.height)
        context.fill(Path(rect), with: .color(style.annotation.opacity(0.12)))

      case .xMarker(_, let x, _):
        var path = Path()
        path.move(to: CGPoint(x: x, y: plot.minY))
        path.addLine(to: CGPoint(x: x, y: plot.maxY))
        context.stroke(path, with: .color(style.annotation), lineWidth: 1)
      }
    }
  }

  private func drawSeries(
    _ series: [PlotResolvedSeriesGeometry],
    context: inout GraphicsContext
  ) {
    for (index, item) in series.enumerated() {
      let color = style.palette[index % style.palette.count].opacity(item.opacity)
      switch item.shape {
      case .line(let line):
        drawLine(line, context: &context, color: color)

      case .area(let area):
        for polygon in area.polygons {
          guard let path = closedPath(points: polygon) else { continue }
          context.fill(path, with: .color(color.opacity(style.areaOpacity)))
        }
        drawLine(area.line, context: &context, color: color)

      case .candles(let candles):
        drawCandles(candles, opacity: item.opacity, context: &context)
      }
    }
  }

  private func drawLine(
    _ line: PlotLineGeometry,
    context: inout GraphicsContext,
    color: Color
  ) {
    for segment in line.segments {
      if let point = segment.first, segment.count == 1 {
        let diameter = style.pointRadius * 2
        let rect = CGRect(
          x: point.x - style.pointRadius,
          y: point.y - style.pointRadius,
          width: diameter,
          height: diameter
        )
        context.fill(Path(ellipseIn: rect), with: .color(color))
        continue
      }
      guard let path = openPath(points: segment) else { continue }
      context.stroke(
        path,
        with: .color(color),
        style: StrokeStyle(lineWidth: style.lineWidth, lineCap: .round, lineJoin: .round)
      )
    }
  }

  private func drawCandles(
    _ candles: [PlotCandleGeometry],
    opacity: Double,
    context: inout GraphicsContext
  ) {
    for candle in candles {
      let color = (candle.isRising ? style.risingCandle : style.fallingCandle).opacity(opacity)
      var wick = Path()
      wick.move(to: CGPoint(x: candle.x, y: candle.highY))
      wick.addLine(to: CGPoint(x: candle.x, y: candle.lowY))
      context.stroke(wick, with: .color(color), lineWidth: 1)

      let body = CGRect(
        x: candle.x - candle.bodyWidth / 2,
        y: min(candle.openY, candle.closeY),
        width: candle.bodyWidth,
        height: max(1, abs(candle.closeY - candle.openY))
      )
      context.fill(Path(body), with: .color(color))
    }
  }

  private func drawLabels(context: inout GraphicsContext, layout: PlotLayout) {
    let plot = layout.transform.plotRect

    for tick in layout.xTicks {
      let x = layout.transform.xScale.position(for: tick.value)
      context.draw(
        axisText(tick.label),
        at: CGPoint(x: x, y: plot.maxY + 6),
        anchor: .top
      )
    }

    for tick in layout.yTicks {
      let y = layout.transform.yScale.position(for: tick.value)
      context.draw(
        axisText(tick.label),
        at: CGPoint(x: plot.minX - 6, y: y),
        anchor: .trailing
      )
    }

    if !scene.xAxis.label.isEmpty {
      context.draw(
        axisTitle(scene.xAxis.label),
        at: CGPoint(x: plot.midX, y: layout.size.height - 2),
        anchor: .bottom
      )
    }

    if !scene.yAxis.label.isEmpty {
      context.draw(
        axisTitle(scene.yAxis.label),
        at: CGPoint(x: plot.minX, y: 2),
        anchor: .topLeading
      )
    }
  }

  private func measuredSize(of label: String, context: GraphicsContext) -> CGSize {
    context.resolve(axisText(label)).measure(in: CGSize(width: 10_000, height: 10_000))
  }

  private func axisText(_ value: String) -> Text {
    Text(value)
      .font(.system(size: 9, design: .monospaced))
      .foregroundStyle(style.axis)
  }

  private func axisTitle(_ value: String) -> Text {
    Text(value.uppercased())
      .font(.system(size: 8, weight: .medium, design: .monospaced))
      .foregroundStyle(style.axis)
  }

  private func openPath(points: [PlotCoordinate]) -> Path? {
    guard let first = points.first else { return nil }
    var path = Path()
    path.move(to: first.cgPoint)
    for point in points.dropFirst() { path.addLine(to: point.cgPoint) }
    return path
  }

  private func closedPath(points: [PlotCoordinate]) -> Path? {
    guard var path = openPath(points: points) else { return nil }
    path.closeSubpath()
    return path
  }

  private func drawEmptyState(context: inout GraphicsContext, bounds: CGRect) {
    context.draw(
      Text("No graph data").font(.caption).foregroundStyle(style.axis),
      at: CGPoint(x: bounds.midX, y: bounds.midY),
      anchor: .center
    )
  }
}

extension PlotRect {
  fileprivate var cgRect: CGRect {
    CGRect(x: minX, y: minY, width: width, height: height)
  }

  fileprivate var midX: Double { minX + width / 2 }
}

extension PlotCoordinate {
  fileprivate var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}
