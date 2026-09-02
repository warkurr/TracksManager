import SwiftUI
import UniformTypeIdentifiers

struct FilesView: View {
    @State private var files: [MediaFile] = []
    @State private var isDropTargeted = false
    @State private var showingImporter = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fichiers")
                        .font(.largeTitle.bold())
                    Text(files.isEmpty ? "Ajoutez des fichiers MKV ou des dossiers." : "\(files.count) fichier\(files.count == 1 ? "" : "s")")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Ajouter", systemImage: "plus") {
                    showingImporter = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            if files.isEmpty {
                ContentUnavailableView {
                    Label("Aucun fichier", systemImage: "film.stack")
                } description: {
                    Text("Glissez-déposez des fichiers MKV ici pour commencer l'analyse.")
                } actions: {
                    Button("Choisir des fichiers") {
                        showingImporter = true
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(isDropTargeted ? Color.accentColor.opacity(0.08) : .clear)
            } else {
                List(files) { file in
                    FileRow(file: file)
                }
                .listStyle(.inset)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            Task {
                await importDroppedFiles(from: providers)
            }
            return true
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.mkv, .folder],
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result else { return }
            add(urls: urls)
        }
    }

    private func add(urls: [URL]) {
        let newFiles = urls
            .filter { $0.pathExtension.lowercased() == "mkv" }
            .map { MediaFile(url: $0) }

        files.append(contentsOf: newFiles.filter { candidate in
            !files.contains(where: { $0.url.standardizedFileURL == candidate.url.standardizedFileURL })
        })
    }

    private func importDroppedFiles(from providers: [NSItemProvider]) async {
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            do {
                let item = try await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier)
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { continue }
                await MainActor.run { add(urls: [url]) }
            } catch {
                // Import errors will be surfaced by the processing/logging layer.
            }
        }
    }
}

private struct FileRow: View {
    let file: MediaFile

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "film")
                .font(.title3)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading) {
                Text(file.name)
                    .lineLimit(1)
                Text(file.url.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text("À analyser")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

private extension UTType {
    static let mkv = UTType(filenameExtension: "mkv") ?? .data
}
