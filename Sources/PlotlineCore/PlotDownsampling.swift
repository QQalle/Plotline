import Foundation

public enum PlotDownsampler {
  /// Reduces a finite, ordered segment while retaining its endpoints and the
  /// local minimum/maximum from each bucket in their original order.
  public static func extremaPreserving(
    _ samples: [PlotSample],
    targetCount: Int
  ) -> [PlotSample] {
    let target = max(2, targetCount)
    guard samples.count > target else { return samples }
    guard target > 2 else { return [samples[0], samples[samples.count - 1]] }
    if target == 3 {
      let interior = samples.dropFirst().dropLast()
      let midpoint = ((samples.first?.y ?? 0) + (samples.last?.y ?? 0)) / 2
      let mostDistinct = interior.max {
        abs(($0.y ?? midpoint) - midpoint) < abs(($1.y ?? midpoint) - midpoint)
      }!
      return [samples[0], mostDistinct, samples[samples.count - 1]]
    }

    let interior = samples.dropFirst().dropLast()
    let bucketCount = max(1, (target - 2) / 2)
    let bucketSize = Double(interior.count) / Double(bucketCount)
    var result: [PlotSample] = [samples[0]]

    for bucket in 0..<bucketCount {
      let lower = Int(floor(Double(bucket) * bucketSize))
      let upper = min(interior.count, Int(ceil(Double(bucket + 1) * bucketSize)))
      guard lower < upper else { continue }
      let startIndex = interior.index(interior.startIndex, offsetBy: lower)
      let endIndex = interior.index(interior.startIndex, offsetBy: upper)
      let slice = interior[startIndex..<endIndex]

      guard let minimum = slice.enumerated().min(by: { ($0.element.y ?? 0) < ($1.element.y ?? 0) }),
        let maximum = slice.enumerated().max(by: { ($0.element.y ?? 0) < ($1.element.y ?? 0) })
      else {
        continue
      }

      if minimum.offset == maximum.offset {
        result.append(minimum.element)
      } else if minimum.offset < maximum.offset {
        result.append(minimum.element)
        result.append(maximum.element)
      } else {
        result.append(maximum.element)
        result.append(minimum.element)
      }
    }

    result.append(samples[samples.count - 1])
    return result
  }
}
