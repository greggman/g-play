import SwiftUI

/// Caches artwork by track and pixel size.
@MainActor
final class ArtworkCache {
  static let shared = ArtworkCache()
  private let cache = NSCache<NSString, UIImage>()

  init() {
    cache.countLimit = 500
  }

  func image(for trackID: Track.ID, size: CGFloat, library: MusicLibrary) async -> UIImage? {
    let key = "\(trackID)-\(Int(size))" as NSString
    if let image = cache.object(forKey: key) { return image }
    guard let image = await library.artwork(for: trackID, size: size) else { return nil }
    cache.setObject(image, forKey: key)
    return image
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
      image = await ArtworkCache.shared.image(for: trackID, size: size * displayScale, library: model.library)
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
