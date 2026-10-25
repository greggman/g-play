import SwiftUI

@main
struct PlayItApp: App {
  @State private var model = AppModel.live()
  @Environment(\.scenePhase) private var scenePhase

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(model)
        .environment(model.router)
        .environment(model.player)
        .task { await model.start() }
    }
    .onChange(of: scenePhase) { _, phase in
      switch phase {
      case .active: model.player.syncWithEngine()
      case .background: model.player.save()
      default: break
      }
    }
  }
}
