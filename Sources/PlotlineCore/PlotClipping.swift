import Foundation

public enum PlotClipper {
  public static func clipPolyline(
    _ points: [PlotCoordinate],
    to rect: PlotRect
  ) -> [[PlotCoordinate]] {
    guard !points.isEmpty else { return [] }
    if points.count == 1 {
      return rect.contains(points[0]) ? [points] : []
    }

    var segments: [[PlotCoordinate]] = []
    var current: [PlotCoordinate] = []

    for (start, end) in zip(points, points.dropFirst()) {
      guard let clipped = clipSegment(from: start, to: end, rect: rect) else {
        if !current.isEmpty {
          segments.append(current)
          current = []
        }
        continue
      }

      if current.last == clipped.start {
        if current.last != clipped.end { current.append(clipped.end) }
      } else {
        if !current.isEmpty { segments.append(current) }
        current = clipped.start == clipped.end ? [clipped.start] : [clipped.start, clipped.end]
      }
    }

    if !current.isEmpty { segments.append(current) }
    return segments
  }

  public static func clipPolygon(
    _ polygon: [PlotCoordinate],
    to rect: PlotRect
  ) -> [PlotCoordinate] {
    guard polygon.count >= 3 else { return [] }
    var output = polygon
    output = clip(
      output,
      isInside: { $0.x >= rect.minX },
      intersection: { start, end in intersectionAtX(rect.minX, start: start, end: end) }
    )
    output = clip(
      output,
      isInside: { $0.x <= rect.maxX },
      intersection: { start, end in intersectionAtX(rect.maxX, start: start, end: end) }
    )
    output = clip(
      output,
      isInside: { $0.y >= rect.minY },
      intersection: { start, end in intersectionAtY(rect.minY, start: start, end: end) }
    )
    output = clip(
      output,
      isInside: { $0.y <= rect.maxY },
      intersection: { start, end in intersectionAtY(rect.maxY, start: start, end: end) }
    )
    return output
  }

  private static func clipSegment(
    from originalStart: PlotCoordinate,
    to originalEnd: PlotCoordinate,
    rect: PlotRect
  ) -> (start: PlotCoordinate, end: PlotCoordinate)? {
    var start = originalStart
    var end = originalEnd
    var startCode = outcode(for: start, rect: rect)
    var endCode = outcode(for: end, rect: rect)

    while true {
      if startCode == 0 && endCode == 0 { return (start, end) }
      if startCode & endCode != 0 { return nil }

      let code = startCode != 0 ? startCode : endCode
      let point: PlotCoordinate

      if code & 8 != 0 {
        point = intersectionAtY(rect.maxY, start: start, end: end)
      } else if code & 4 != 0 {
        point = intersectionAtY(rect.minY, start: start, end: end)
      } else if code & 2 != 0 {
        point = intersectionAtX(rect.maxX, start: start, end: end)
      } else {
        point = intersectionAtX(rect.minX, start: start, end: end)
      }

      if code == startCode {
        start = point
        startCode = outcode(for: start, rect: rect)
      } else {
        end = point
        endCode = outcode(for: end, rect: rect)
      }
    }
  }

  private static func outcode(for point: PlotCoordinate, rect: PlotRect) -> Int {
    var code = 0
    if point.x < rect.minX { code |= 1 }
    if point.x > rect.maxX { code |= 2 }
    if point.y < rect.minY { code |= 4 }
    if point.y > rect.maxY { code |= 8 }
    return code
  }

  private static func clip(
    _ input: [PlotCoordinate],
    isInside: (PlotCoordinate) -> Bool,
    intersection: (PlotCoordinate, PlotCoordinate) -> PlotCoordinate
  ) -> [PlotCoordinate] {
    guard var previous = input.last else { return [] }
    var output: [PlotCoordinate] = []
    var previousInside = isInside(previous)

    for current in input {
      let currentInside = isInside(current)
      if currentInside {
        if !previousInside { output.append(intersection(previous, current)) }
        output.append(current)
      } else if previousInside {
        output.append(intersection(previous, current))
      }
      previous = current
      previousInside = currentInside
    }
    return output
  }

  private static func intersectionAtX(
    _ x: Double,
    start: PlotCoordinate,
    end: PlotCoordinate
  ) -> PlotCoordinate {
    let delta = end.x - start.x
    guard delta != 0 else { return PlotCoordinate(x: x, y: start.y) }
    let t = (x - start.x) / delta
    return PlotCoordinate(x: x, y: start.y + t * (end.y - start.y))
  }

  private static func intersectionAtY(
    _ y: Double,
    start: PlotCoordinate,
    end: PlotCoordinate
  ) -> PlotCoordinate {
    let delta = end.y - start.y
    guard delta != 0 else { return PlotCoordinate(x: start.x, y: y) }
    let t = (y - start.y) / delta
    return PlotCoordinate(x: start.x + t * (end.x - start.x), y: y)
  }
}
