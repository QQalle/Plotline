# Changelog

All notable changes will be documented in this file.

The project follows semantic versioning after its first tagged release.

## Unreleased

- Add an opt-in, reduced-motion-aware live endpoint indicator for line and area series.
- Create the Plotline Swift package scaffold.
- Add initial numeric domains, scale transforms, graph models, annotations, and SwiftUI Canvas rendering.
- Add iOS 17+, macOS 14+, and experimental watchOS 10+ platform declarations.
- Add hosted CI coverage for Swift tests and Apple platform builds.
- Add deterministic input normalization with explicit gap and duplicate-X policies.
- Add padded and viewport domains, clamped scale lookup, nice ticks, adaptive label density, measured insets, and reversible plot transforms.
- Add renderer-independent line, area, candle, and annotation geometry with clipping and extrema-preserving downsampling.
- Refactor the SwiftUI Canvas renderer to draw core geometry instead of maintaining separate coordinate math.
- Add viewport-aware nearest and interpolated hit testing, including candles, gaps, and annotations.
- Add configurable drag scrubbing, crosshair selection, optional binding and callback APIs.
- Add VoiceOver summaries, adjustable selection, and audio graph metadata through `AXChartDescriptor`.
- Enforce Swift formatting and warning-free tests in continuous integration.
