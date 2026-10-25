import SwiftUI

/// Caches artwork by album (tracks on an album share artwork) and pixel size.
@MainActor
final class ArtworkCache {
  static let shared = ArtworkCache()
  private let cache = NSCache<NSString, UIImage>()

  init() {
    cache.countLimit = 1_000
  }

  func cachedImage(key: UInt64, size: CGFloat) -> UIImage? {
    cache.object(forKey: Self.key(key, size))
  }

  /// - Parameter key: the album ID, or the track ID if it isn't known.
  func image(for trackID: Track.ID, key: UInt64, size: CGFloat, library: MusicLibrary) async -> UIImage? {
    let key = Self.key(key, size)
    if let image = cache.object(forKey: key) { return image }
    guard let image = await library.artwork(for: trackID, size: size) else { return nil }
    cache.setObject(image, forKey: key)
    return image
  }

  private static func key(_ key: UInt64, _ size: CGFloat) -> NSString {
    "\(key)-\(Int(size))" as NSString
  }
}

/// A track's (or album's) artwork with a placeholder while loading or when
/// there is none.
struct ArtworkView: View {
  let trackID: Track.ID?
  var size: CGFloat
  var cornerRadius: CGFloat = 6

  @Environment(AppModel.self) private var model
  @Environment(\.displayScale) private var displayScale
  @State private var image: UIImage?

  var body: some View {
    ZStack {
      if let image {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
      } else {
        Rectangle()
          .fill(.quaternary)
          .overlay {
            Image(systemName: "music.note")
              .font(.system(size: size * 0.4))
              .foregroundStyle(.secondary)
          }
      }
    }
    .frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    .accessibilityHidden(true)
    .task(id: trackID) {
      guard let trackID else {
        image = nil
        return
      }
      let key = model.track(trackID)?.albumID ?? trackID
      let pixels = size * displayScale
      // Show cached artwork immediately rather than after a placeholder frame.
      if let cached = ArtworkCache.shared.cachedImage(key: key, size: pixels) {
        image = cached
        return
      }
      image = nil
      image = await ArtworkCache.shared.image(for: trackID, key: key, size: pixels, library: model.library)
    }
  }
}

/// Artwork that fills the available width, for album headers and Now Playing.
struct LargeArtworkView: View {
  let trackID: Track.ID?

  var body: some View {
    GeometryReader { geometry in
      let side = min(geometry.size.width, geometry.size.height)
      ArtworkView(trackID: trackID, size: side, cornerRadius: 12)
        .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .aspectRatio(1, contentMode: .fit)
  }
}
