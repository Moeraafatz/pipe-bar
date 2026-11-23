import AppKit
import PipeBarCore
import PipeBarUI
import SwiftUI

@main
struct PipeBarApp: App {
    @State private var appState: PipeAppState
    @State private var hudController: FloatingPipeHUD?

    init() {
        let store = try? RecipeStore()
        let state = PipeAppState(store: store, isPreviewSnapshot: false)
        _appState = State(initialValue: state)
        _hudController = State(initialValue: FloatingPipeHUD(state: state))
    }

    var body: some Scene {
        MenuBarExtra {
            RootPipeView(state: appState, width: 510)
                .task {
                    await appState.bootstrap()
                }
        } label: {
            Image(systemName: "terminal.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
