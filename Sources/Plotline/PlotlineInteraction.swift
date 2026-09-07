import PlotlineCore

public enum PlotSelectionPersistence: Sendable, Hashable {
  case whileInteracting
  case persistent
}

public struct PlotlineInteractionConfiguration: Sendable, Hashable {
  public var isEnabled: Bool
  public var selectionMode: PlotSelectionMode
  public var persistence: PlotSelectionPersistence
  public var annotationTolerance: Double
  public var allowsAccessibilityAdjustment: Bool

  public init(
    isEnabled: Bool = true,
    selectionMode: PlotSelectionMode = .nearest,
    persistence: PlotSelectionPersistence = .whileInteracting,
    annotationTolerance: Double = 8,
    allowsAccessibilityAdjustment: Bool = true
  ) {
    self.isEnabled = isEnabled
    self.selectionMode = selectionMode
    self.persistence = persistence
    self.annotationTolerance = annotationTolerance.isFinite ? max(0, annotationTolerance) : 8
    self.allowsAccessibilityAdjustment = allowsAccessibilityAdjustment
  }

  public static let standard = PlotlineInteractionConfiguration()
  public static let disabled = PlotlineInteractionConfiguration(isEnabled: false)
}
