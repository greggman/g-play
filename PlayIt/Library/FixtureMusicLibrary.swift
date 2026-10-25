import UIKit

/// A generated library for the Simulator, which has no Music library.
/// Deterministic for a given track count, so UI tests can rely on names.
@MainActor
final class FixtureMusicLibrary: MusicLibrary {
  private let trackCount: Int
  private var artworkColors: [Track.ID: (album: String, hue: CGFloat)] = [:]

  init(trackCount: Int = 400) {
    self.trackCount = trackCount
  }

  var authorization: LibraryAuthorization { .authorized }

  func requestAuthorization() async -> LibraryAuthorization { .authorized }

  func loadSnapshot() async -> LibrarySnapshot {
    let count = trackCount
    let (snapshot, colors) = await Task.detached(priority: .userInitiated) {
      let (tracks, playlists) = Self.generate(trackCount: count)
      let colors = Dictionary(uniqueKeysWithValues: tracks.map {
        ($0.id, (album: $0.album, hue: CGFloat($0.albumID % 360) / 360))
      })
      return (LibrarySnapshot(tracks: tracks, systemPlaylists: playlists), colors)
    }.value
    artworkColors = colors
    return snapshot
  }

  func artwork(for trackID: Track.ID, size: CGFloat) async -> UIImage? {
    guard let info = artworkColors[trackID] else { return nil }
    return await Task.detached(priority: .userInitiated) {
      Self.renderArtwork(title: info.album, hue: info.hue, size: size)
    }.value
  }

  func changes() -> AsyncStream<Void> {
    AsyncStream { _ in }
  }

  // MARK: - Generation

  nonisolated private static let firstWords = [
    "The", "Midnight", "Electric", "Silver", "Velvet", "Golden", "Broken", "Neon", "Crystal",
    "Wild", "Quiet", "Café", "Ocean", "Paper", "Iron", "Lunar", "Hollow", "Bright", "Crimson",
    "Distant", "Echo", "Frozen", "Gentle", "Hidden", "Ivory", "Jade", "Kinetic", "Lost",
  ]
  nonisolated private static let secondWords = [
    "Rivers", "Engines", "Hearts", "Lights", "Dreams", "Wolves", "Gardens", "Machines", "Skies",
    "Roads", "Mirrors", "Signals", "Shadows", "Waves", "Cities", "Birds", "Stars", "Fires",
    "Bells", "Clouds", "Doors", "Fields", "Ghosts", "Islands", "Kites", "Lanterns", "Moons",
  ]
  nonisolated private static let titleWords = [
    "Love", "Night", "Run", "Home", "Fall", "Rain", "Sun", "Away", "Tonight", "Forever",
    "Blue", "Again", "Dance", "Light", "Fire", "Time", "Sky", "Dream", "Heart", "Road",
    "Señorita", "Über", "Naïve", "Déjà Vu", "Summer", "Winter", "Gold", "Ghost", "Song",
  ]

  nonisolated static func generate(trackCount: Int) -> ([Track], [Playlist]) {
    var rng = SplitMix64(seed: 42)
    let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let artistCount = max(1, trackCount / 40)
    let albumCount = max(1, trackCount / 10)

    func pick(_ words: [String]) -> String {
      words[Int(rng.next() % UInt64(words.count))]
    }

    let artistNames = (0..<artistCount).map { i -> String in
      // A few names with digits or leading articles, to exercise sorting.
      switch i % 13 {
      case 5: return "\(i + 1) \(pick(secondWords))"
      case 7: return "A \(pick(secondWords).dropLast()) Named \(pick(titleWords))"
      default: return "\(pick(firstWords)) \(pick(secondWords)) \(i)"
      }
    }
    let albums = (0..<albumCount).map { i in
      (title: "\(pick(firstWords)) \(pick(titleWords)) \(i)", artist: i % artistCount)
    }

    var tracks: [Track] = []
    var trackNumberInAlbum = [Int](repeating: 0, count: albumCount)
    for i in 0..<trackCount {
      // The first tracks fill albums in order so every album has some.
      let albumIndex = i < albumCount ? i : Int(rng.next() % UInt64(albumCount))
      let album = albums[albumIndex]
      trackNumberInAlbum[albumIndex] += 1
      let neverPlayed = rng.next() % 5 == 0
      let daysAgo = Double(rng.next() % 500)
      tracks.append(Track(
        id: UInt64(10_000 + i),
        title: "\(pick(titleWords)) \(pick(titleWords)) \(i)",
        artist: artistNames[album.artist],
        artistID: UInt64(1_000 + album.artist),
        album: album.title,
        albumID: UInt64(5_000 + albumIndex),
        albumArtist: artistNames[album.artist],
        trackNumber: trackNumberInAlbum[albumIndex],
        discNumber: 1,
        duration: 120 + Double(rng.next() % 240),
        dateAdded: now.addingTimeInterval(-Double(rng.next() % 1_000) * 86_400),
        lastPlayedDate: neverPlayed ? nil : now.addingTimeInterval(-daysAgo * 86_400),
        playCount: neverPlayed ? 0 : Int(rng.next() % 50) + 1))
    }

    let playlists = (0..<3).map { i in
      Playlist(
        id: .system(UInt64(90_000 + i)),
        name: ["Road Trip", "Focus", "Favorites"][i],
        trackIDs: (0..<min(25, trackCount)).map { _ in tracks[Int(rng.next() % UInt64(trackCount))].id })
    }
    return (tracks, playlists)
  }

  // MARK: - Artwork

  nonisolated private static func renderArtwork(title: String, hue: CGFloat, size: CGFloat) -> UIImage {
    let bounds = CGRect(x: 0, y: 0, width: size, height: size)
    return UIGraphicsImageRenderer(bounds: bounds).image { context in
      let colors = [
        UIColor(hue: hue, saturation: 0.65, brightness: 0.85, alpha: 1).cgColor,
        UIColor(hue: (hue + 0.12).truncatingRemainder(dividingBy: 1), saturation: 0.75, brightness: 0.45, alpha: 1).cgColor,
      ]
      let gradient = CGGradient(colorsSpace: nil, colors: colors as CFArray, locations: [0, 1])!
      context.cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size, y: size), options: [])
      let initials = title.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
      let attributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: size * 0.36, weight: .bold),
        .foregroundColor: UIColor.white.withAlphaComponent(0.9),
      ]
      let text = initials as NSString
      let textSize = text.size(withAttributes: attributes)
      text.draw(at: CGPoint(x: (size - textSize.width) / 2, y: (size - textSize.height) / 2), withAttributes: attributes)
    }
  }
}
