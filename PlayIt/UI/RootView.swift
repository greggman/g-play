import SwiftUI

struct RootView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    switch model.loadState {
    case .loading:
      ProgressView("Loading Library…")
    case .needsAuthorization(let status):
      AuthorizationView(status: status)
    case .loaded:
      Text("Loaded \(model.snapshot.tracks.count) tracks")
    }
  }
}
