import SwiftUI

struct ContentView: View {
    @State private var selection: SidebarItem? = .files

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.title, systemImage: item.systemImage)
                    .tag(item)
            }
            .navigationTitle("TracksManager")
            .listStyle(.sidebar)
        } detail: {
            Group {
                switch selection ?? .files {
                case .files:
                    FilesView()
                case .processing:
                    ProcessingView()
                case .presets:
                    PlaceholderView(title: "Presets", systemImage: "slider.horizontal.3")
                case .history:
                    PlaceholderView(title: "Historique", systemImage: "clock.arrow.circlepath")
                }
            }
            .frame(minWidth: 760, minHeight: 520)
        }
    }
}

enum SidebarItem: String, CaseIterable, Identifiable {
    case files
    case processing
    case presets
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .files: "Fichiers"
        case .processing: "Traitement"
        case .presets: "Presets"
        case .history: "Historique"
        }
    }

    var systemImage: String {
        switch self {
        case .files: "film.stack"
        case .processing: "gearshape.2"
        case .presets: "slider.horizontal.3"
        case .history: "clock.arrow.circlepath"
        }
    }
}

#Preview {
    ContentView()
}
