import Foundation

public struct PlotValueFormatter: Sendable {
    private let format: @Sendable (Double) -> String

    public init(_ format: @escaping @Sendable (Double) -> String) {
        self.format = format
    }

    public func callAsFunction(_ value: Double) -> String {
        format(value)
    }

    public static func number(decimals: Int = 0) -> PlotValueFormatter {
        let safeDecimals = max(0, min(6, decimals))
        return PlotValueFormatter { value in
            String(format: "%.*f", safeDecimals, value)
        }
    }
}

public struct PlotAxis: Sendable {
    public var label: String
    public var domain: PlotDomain?
    public var direction: PlotAxisDirection
    public var formatter: PlotValueFormatter

    public init(
        label: String = "",
        domain: PlotDomain? = nil,
        direction: PlotAxisDirection = .normal,
        formatter: PlotValueFormatter = .number()
    ) {
        self.label = label
        self.domain = domain
        self.direction = direction
        self.formatter = formatter
    }
}

public struct PlotSample: Sendable, Hashable {
    public var x: Double
    public var y: Double?

    public init(x: Double, y: Double?) {
        self.x = x
        self.y = y
    }
}

public struct PlotCandle: Sendable, Hashable {
    public var x: Double
    public var open: Double
    public var high: Double
    public var low: Double
    public var close: Double

    public init(x: Double, open: Double, high: Double, low: Double, close: Double) {
        self.x = x
        self.open = open
        self.high = high
        self.low = low
        self.close = close
    }
}

public enum PlotBaseline: Sendable, Hashable {
    case zero
    case value(Double)
    case lowerDomainBound
}

public enum PlotSeriesData: Sendable, Hashable {
    case line([PlotSample])
    case area([PlotSample], baseline: PlotBaseline = .lowerDomainBound)
    case candles([PlotCandle])
}

public struct PlotSeries: Identifiable, Sendable, Hashable {
    public var id: String
    public var name: String
    public var data: PlotSeriesData
    public var opacity: Double

    public init(id: String, name: String, data: PlotSeriesData, opacity: Double = 1) {
        self.id = id
        self.name = name
        self.data = data
        self.opacity = max(0, min(1, opacity))
    }
}

public enum PlotAnnotation: Identifiable, Sendable, Hashable {
    case xRange(id: String, lowerBound: Double, upperBound: Double, label: String?)
    case xMarker(id: String, value: Double, label: String?)

    public var id: String {
        switch self {
        case .xRange(let id, _, _, _), .xMarker(let id, _, _): id
        }
    }
}

public struct PlotScene: Sendable {
    public var xAxis: PlotAxis
    public var yAxis: PlotAxis
    public var series: [PlotSeries]
    public var annotations: [PlotAnnotation]
    public var accessibilityLabel: String

    public init(
        xAxis: PlotAxis = PlotAxis(),
        yAxis: PlotAxis = PlotAxis(),
        series: [PlotSeries],
        annotations: [PlotAnnotation] = [],
        accessibilityLabel: String = "Graph"
    ) {
        self.xAxis = xAxis
        self.yAxis = yAxis
        self.series = series
        self.annotations = annotations
        self.accessibilityLabel = accessibilityLabel
    }

    public var automaticXDomain: PlotDomain? {
        PlotDomain.enclosing(series.flatMap(\.finiteXValues))
    }

    public var automaticYDomain: PlotDomain? {
        PlotDomain.enclosing(series.flatMap(\.finiteYValues))
    }
}

public extension PlotSeries {
    var finiteXValues: [Double] {
        switch data {
        case .line(let samples), .area(let samples, _):
            samples.compactMap { sample in sample.x.isFinite && sample.y?.isFinite == true ? sample.x : nil }
        case .candles(let candles):
            candles.compactMap { candle in candle.isFinite ? candle.x : nil }
        }
    }

    var finiteYValues: [Double] {
        switch data {
        case .line(let samples), .area(let samples, _):
            return samples.compactMap { sample -> Double? in
                guard sample.x.isFinite, let y = sample.y, y.isFinite else { return nil }
                return y
            }
        case .candles(let candles):
            return candles.flatMap { candle in candle.isFinite ? [candle.low, candle.high] : [] }
        }
    }
}

private extension PlotCandle {
    var isFinite: Bool {
        x.isFinite && open.isFinite && high.isFinite && low.isFinite && close.isFinite
    }
}
