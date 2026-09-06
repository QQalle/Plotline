# Plotline

Plotline is an experimental, native Swift graph engine for apps that need precise layout, live data, annotations, and full control over interaction and presentation.

It is being built to replace a mixed WebView and Swift Charts stack in a running app, while keeping the public package numeric and domain-neutral.

## Status

Plotline is at the initial scaffold stage and is not ready for production use. The API will change before `0.1.0`.

The repository currently provides:

- numeric line, area, and candlestick data models;
- automatic and explicit numeric domains;
- normal and reversed scale transforms;
- a native SwiftUI Canvas renderer;
- multiple series, gaps, horizontal ranges, and vertical markers;
- initial unit tests for domains, scales, and scene data.

Scrubbing, selection, adaptive ticks, downsampling, accessibility chart descriptors, deterministic snapshots, and live-update optimization are next.

## Requirements

- Swift 6+
- iOS 17+
- macOS 14+
- watchOS 10+ (experimental)

Plotline has no third-party runtime dependencies.

## Installation

Add Plotline as a Swift Package dependency:

```swift
.package(url: "https://github.com/QQalle/Plotline.git", branch: "main")
```

Use a tagged version instead of `main` after the first release.

## Example

```swift
import Plotline
import SwiftUI

struct PaceGraph: View {
    let scene = PlotScene(
        xAxis: PlotAxis(label: "Distance"),
        yAxis: PlotAxis(label: "Pace", direction: .reversed),
        series: [
            PlotSeries(
                id: "pace",
                name: "Pace",
                data: .line([
                    PlotSample(x: 0, y: 6.1),
                    PlotSample(x: 1, y: 5.8),
                    PlotSample(x: 2, y: 5.4),
                    PlotSample(x: 3, y: 5.7)
                ])
            )
        ],
        annotations: [
            .xRange(id: "effort", lowerBound: 1.2, upperBound: 2.4, label: "Effort")
        ],
        accessibilityLabel: "Pace by distance"
    )

    var body: some View {
        PlotlineView(scene: scene)
            .frame(height: 280)
    }
}
```

## Design principles

- One deterministic coordinate system for data, annotations, and hit testing.
- A testable rendering-independent core.
- Native rendering with no WebView or JavaScript bridge.
- Running-specific concepts remain in the consuming app.
- Features earn their place through real consumers.

See the [roadmap](Documentation.docc/Roadmap.md) for the path to `0.1.0`.

## Contributing

Issues and pull requests are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md).

## License

Plotline is available under the MIT License. See [LICENSE](LICENSE).
