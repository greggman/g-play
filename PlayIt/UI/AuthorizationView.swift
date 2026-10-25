import SwiftUI

/// Shown when the app can't read the music library.
struct AuthorizationView: View {
  let status: LibraryAuthorization
  @Environment(\.openURL) private var openURL

  var body: some View {
    ContentUnavailableView {
      Label("No Access to Music", systemImage: "music.note.list")
    } description: {
      switch status {
      case .restricted:
        Text("Access to your music library is restricted on this device.")
      default:
        Text("Play-It needs access to your music library to play it. You can allow access in Settings.")
      }
    } actions: {
      if status != .restricted {
        Button("Open Settings") {
          if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
        }
        .buttonStyle(.borderedProminent)
      }
    }
  }
}
