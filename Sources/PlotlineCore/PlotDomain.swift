import Foundation

public struct PlotDomain: Sendable, Hashable {
    public let lowerBound: Double
    public let upperBound: Double

    public init?(lowerBound: Double, upperBound: Double) {
        guard lowerBound.isFinite, upperBound.isFinite, lowerBound <= upperBound else {
            return nil
        }
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }

    public static func enclosing<S: Sequence>(_ values: S) -> PlotDomain? where S.Element == Double {
        var lower: Double?
        var upper: Double?

        for value in values where value.isFinite {
            lower = min(lower ?? value, value)
            upper = max(upper ?? value, value)
        }

        guard let lower, let upper else { return nil }
        return PlotDomain(lowerBound: lower, upperBound: upper)
    }

    public func expandedIfConstant(minimumSpan: Double = 1) -> PlotDomain {
        guard lowerBound == upperBound else { return self }
        let requestedSpan = minimumSpan.isFinite && minimumSpan > 0 ? minimumSpan : 1
        let adaptiveSpan = max(requestedSpan, abs(lowerBound) * 0.1)
        return PlotDomain(
            lowerBound: lowerBound - adaptiveSpan / 2,
            upperBound: upperBound + adaptiveSpan / 2
        )!
    }
}

public enum PlotAxisDirection: Sendable, Hashable {
    case normal
    case reversed
}

public struct PlotScale: Sendable, Hashable {
    public let domain: PlotDomain
    public let range: ClosedRange<Double>
    public let direction: PlotAxisDirection

    public init(domain: PlotDomain, range: ClosedRange<Double>, direction: PlotAxisDirection = .normal) {
        self.domain = domain.expandedIfConstant()
        self.range = range
        self.direction = direction
    }

    public func position(for value: Double) -> Double {
        let domainSpan = domain.upperBound - domain.lowerBound
        let unclampedUnit = (value - domain.lowerBound) / domainSpan
        let unit = direction == .normal ? unclampedUnit : 1 - unclampedUnit
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }

    public func value(at position: Double) -> Double {
        let rangeSpan = range.upperBound - range.lowerBound
        guard rangeSpan != 0 else { return domain.lowerBound }
        let rawUnit = (position - range.lowerBound) / rangeSpan
        let unit = direction == .normal ? rawUnit : 1 - rawUnit
        return domain.lowerBound + unit * (domain.upperBound - domain.lowerBound)
    }
}
