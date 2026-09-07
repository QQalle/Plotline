# Core engine

Plotline separates graph calculation from drawing so that scales, annotations, and hit testing share one deterministic coordinate system.

## Prepare data

`PlotDataNormalizer` validates values, preserves explicit gaps, orders each segment by X, and resolves duplicate X values. The default policy keeps the last duplicate. Alternative policies keep the first value or average samples; averaging candles preserves the first open, true high and low, and last close.

## Resolve layout

`PlotLayoutEngine` combines a scene, output size, and measured label metrics. It resolves automatic, explicit, or viewport domains; creates readable ticks; reduces tick density when labels cannot fit; reserves plot insets; and returns one `PlotTransform`.

Normal Y axes use Cartesian presentation, where larger values are higher on screen. A reversed Y axis is useful for values such as pace, where a smaller numeric duration should appear higher. Source values and formatted labels are never negated.

## Build geometry

`PlotGeometryBuilder` produces platform-neutral coordinates for every visible layer. Line and area series preserve gaps, large series are downsampled relative to pixel width, output is clipped to the plot rectangle, and annotations use the layout's exact transform.

The SwiftUI module consumes this result and performs drawing only. Consumers that need snapshots or a different graphics backend can use the same layout and geometry types.

## Select values

`PlotHitTester` uses the resolved layout transform, so hit testing and drawing cannot drift into separate coordinate systems. Nearest selection snaps the crosshair to the closest visible X value. Interpolated selection follows the pointer between samples without bridging an explicit gap. Selections contain a formatted-data-independent X value, every selected series value, screen coordinates, selection sources, and matching annotation IDs.

`PlotAccessibilityBuilder` derives stable, platform-neutral summaries from the same normalized scene. The SwiftUI renderer adds adjustable selection and an `AXChartDescriptor`, allowing VoiceOver users to inspect adjacent values and use Apple's audio graph experience.
