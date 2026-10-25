import Foundation

/// Orders the whole library so that tracks not played recently tend to come
/// first. The goal is to work through the entire library: an unweighted
/// shuffle makes repeats of recently heard tracks more likely.
enum WeightedShuffle {
  /// Days since last played stop adding weight after this.
  static let maxDays = 365.0
  /// Weight of a track that has never been played.
  static let neverPlayedWeight = maxDays + 1

  /// Weight depends only on how long ago the track was last played.
  static func weight(lastPlayed: Date?, now: Date) -> Double {
    guard let lastPlayed else { return neverPlayedWeight }
    let days = max(0, now.timeIntervalSince(lastPlayed) / 86_400)
    return min(days, maxDays) + 1
  }

  /// Weighted random sampling without replacement (Efraimidis–Spirakis):
  /// each track gets key `u^(1/w)` and the order is by descending key.
  /// `log(u) / w` gives the same order without underflow.
  ///
  /// - Parameter recentlyPlayed: plays this app knows about that the library
  ///   may not reflect yet. The later of the two dates is used.
  static func order<R: RandomNumberGenerator>(
    _ tracks: [Track],
    now: Date = .now,
    recentlyPlayed: [Track.ID: Date] = [:],
    using rng: inout R
  ) -> [Track.ID] {
    var keyed: [(key: Double, id: Track.ID)] = []
    keyed.reserveCapacity(tracks.count)
    for track in tracks {
      let lastPlayed = [track.lastPlayedDate, recentlyPlayed[track.id]].compactMap { $0 }.max()
      let w = weight(lastPlayed: lastPlayed, now: now)
      // u in (0, 1]
      let u = 1 - Double.random(in: 0..<1, using: &rng)
      keyed.append((log(u) / w, track.id))
    }
    keyed.sort { $0.key > $1.key }
    return keyed.map(\.id)
  }

  static func order(
    _ tracks: [Track],
    now: Date = .now,
    recentlyPlayed: [Track.ID: Date] = [:]
  ) -> [Track.ID] {
    var rng = SystemRandomNumberGenerator()
    return order(tracks, now: now, recentlyPlayed: recentlyPlayed, using: &rng)
  }
}

/// Small deterministic generator for tests and fixtures.
struct SplitMix64: RandomNumberGenerator, Sendable {
  private var state: UInt64

  init(seed: UInt64) {
    state = seed
  }

  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}
