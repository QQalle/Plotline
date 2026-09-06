import Foundation

public struct PlotTick: Sendable, Hashable {
  public let value: Double
  public let label: String

  public init(value: Double, label: String) {
    self.value = value
    self.label = label
  }
}

public enum PlotTickGenerator {
  public static func ticks(for domain: PlotDomain, axis: PlotAxis) -> [PlotTick] {
    values(for: domain, targetCount: axis.targetTickCount).map {
      PlotTick(value: $0, label: axis.formatter($0))
    }
  }

  public static func values(for domain: PlotDomain, targetCount: Int = 5) -> [Double] {
    let expanded = domain.expandedIfConstant()
    let count = max(2, min(12, targetCount))
    let step = niceStep(for: expanded.span / Double(count - 1))
    guard step.isFinite, step > 0 else { return [expanded.lowerBound, expanded.upperBound] }

    let first = ceil(expanded.lowerBound / step) * step
    let last = floor(expanded.upperBound / step) * step
    var values: [Double] = []
    var value = first
    var iteration = 0

    while value <= last + step * 1e-10, iteration < 1_000 {
      let normalized = abs(value) < step * 1e-12 ? 0 : value
      values.append(normalized)
      value += step
      iteration += 1
    }

    if values.count < 2 {
      return [expanded.lowerBound, expanded.upperBound]
    }
    return values
  }

  public static func niceStep(for rawStep: Double) -> Double {
    guard rawStep.isFinite, rawStep > 0 else { return 1 }
    let magnitude = pow(10, floor(log10(rawStep)))
    let residual = rawStep / magnitude
    let niceResidual: Double

    switch residual {
    case ..<1.5: niceResidual = 1
    case ..<3: niceResidual = 2
    case ..<7: niceResidual = 5
    default: niceResidual = 10
    }
    return niceResidual * magnitude
  }
}
