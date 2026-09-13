#if DEBUG
import SwiftUI

/// Screenshot-only routes reuse the production views and their current data.
struct VisualFixtureView: View {
    let name: String
    @Bindable var client: GameClient
    @Bindable var store: PackStore
    @State private var draft = GameSettings()

    var body: some View {
        Group {
            switch name {
            case "join":
                JoinView(client: client, close: {}, initialCode: "K7MX")
            case "name":
                JoinView(client: client, close: {}, initialStep: 1, initialCode: "K7MX")
            case "characters":
                JoinView(client: client, close: {}, initialStep: 2, initialCode: "K7MX")
            case "code-error":
                JoinView(client: client, close: {}, initialStep: 0, initialCode: "K7MZ", initialError: true)
            case "settings":
                PreferencesView(client: client, store: store)
            case "setup":
                fixtureSheet {
                    SetupView(client: client, store: store, original: client.room?.settings ?? GameSettings())
                        .id(client.room?.roomID ?? "loading-setup")
                }
            case "pack-selection":
                PackSelectionView(client: client, store: store, draft: $draft)
            case "shop":
                ShopView(client: client, store: store)
            case "pack-detail":
                if let pack = Pack.all.first(where: { $0.id == "isbryderen" }) {
                    PackDetailView(pack: pack, client: client, store: store)
                }
            case "pack-owned":
                if let pack = Pack.all.first(where: { $0.id == "isbryderen" }) {
                    PackOwnedView(pack: pack)
                }
            case "bundle":
                BundleView(client: client, store: store)
            case "adult":
                AdultView(client: client)
            case "results":
                fixtureSheet {
                    if let room = client.room { ResultsView(room: room) }
                    else { ProgressView("Henter rundens resultat…").frame(maxWidth: .infinity, maxHeight: .infinity) }
                }
            default:
                EmptyView()
            }
        }
        .task { await store.load() }
        .onAppear {
            draft = client.room?.settings ?? GameSettings()
        }
        .onChange(of: client.room?.roomID) { _, _ in
            draft = client.room?.settings ?? GameSettings()
        }
    }

    private func fixtureSheet<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        Group {
            if let room = client.room {
                RoomView(client: client, store: store, room: room, showSetup: {}, showProfile: {}, showRules: {}, showPreferences: {}, leave: {})
            } else {
                HomeView(client: client, show: { _ in }, join: {})
            }
        }
        .sheet(isPresented: .constant(true)) {
            NavigationStack { content() }
                .presentationDragIndicator(.visible).preferredColorScheme(.dark).tint(.lime)
        }
    }
}
#endif
