import SwiftUI

@main
struct SolitaireApp: App {
    @StateObject private var game = KlondikeGame()

    var body: some Scene {
        WindowGroup {
            GameView(game: game)
                .frame(minWidth: 980, minHeight: 700)
                .onAppear { game.startIfNeeded() }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1140, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Nouvelle partie") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { game.newGame() }
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(replacing: .undoRedo) {
                Button("Annuler le coup") {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { game.undo() }
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!game.canUndo)
            }
        }
    }
}
