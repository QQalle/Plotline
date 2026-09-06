import XCTest

@testable import PlotlineCore

final class PlotDomainTests: XCTestCase {
  func testDomainIgnoresNonFiniteValues() {
    let domain = PlotDomain.enclosing([Double.nan, 8, -2, .infinity, 3])

    XCTAssertEqual(domain?.lowerBound, -2)
    XCTAssertEqual(domain?.upperBound, 8)
  }

  func testNormalScaleRoundTrips() throws {
    let domain = try XCTUnwrap(PlotDomain(lowerBound: 10, upperBound: 20))
    let scale = PlotScale(domain: domain, range: 50...250)

    XCTAssertEqual(scale.position(for: 15), 150, accuracy: 0.000_001)
    XCTAssertEqual(scale.value(at: 150), 15, accuracy: 0.000_001)
  }

  func testReversedScaleKeepsOriginalValues() throws {
    let domain = try XCTUnwrap(PlotDomain(lowerBound: 4, upperBound: 8))
    let scale = PlotScale(domain: domain, range: 0...100, direction: .reversed)

    XCTAssertEqual(scale.position(for: 4), 100, accuracy: 0.000_001)
    XCTAssertEqual(scale.position(for: 8), 0, accuracy: 0.000_001)
    XCTAssertEqual(scale.value(at: 25), 7, accuracy: 0.000_001)
  }

  func testConstantDomainExpandsToFiniteScale() throws {
    let domain = try XCTUnwrap(PlotDomain(lowerBound: 42, upperBound: 42))
    let scale = PlotScale(domain: domain, range: 0...100)

    XCTAssertTrue(scale.position(for: 42).isFinite)
    XCTAssertEqual(scale.position(for: 42), 50, accuracy: 0.000_001)
  }

  func testPaddingCanIncludeZero() throws {
    let domain = try XCTUnwrap(PlotDomain(lowerBound: 10, upperBound: 20))
    let padded = domain.padded(by: 0.1, includeZero: true)

    XCTAssertEqual(padded.lowerBound, 0)
    XCTAssertEqual(padded.upperBound, 21)
  }

  func testClampedScaleLookupStaysInsideDomainAndRange() throws {
    let domain = try XCTUnwrap(PlotDomain(lowerBound: 0, upperBound: 10))
    let scale = PlotScale(domain: domain, range: 20...120)

    XCTAssertEqual(scale.position(for: 100, clamped: true), 120)
    XCTAssertEqual(scale.value(at: -100, clamped: true), 0)
  }
}
