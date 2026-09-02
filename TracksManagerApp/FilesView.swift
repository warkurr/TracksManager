import SwiftUI
import UniformTypeIdentifiers

struct FilesView: View {
    @State private var files: [MediaFile] = []
    @State private var isDropTargeted = false
    @State private var showingImporter = false
    @State private var analysisCoordinator = AnalysisCoordinator()

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
                Button("Analyser tout", systemImage: "waveform.path.ecg") {
                    analyzeAll()
                }
                .disabled(files.isEmpty)
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
                    FileRow(
                        file: file,
                        analysis: analysisCoordinator.analysis(for: file),
                        error: analysisCoordinator.error(for: file),
                        onAnalyze: { analyze(file) }
                    )
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

        let uniqueFiles = newFiles.filter { candidate in
            !files.contains(where: { $0.url.standardizedFileURL == candidate.url.standardizedFileURL })
        }
        files.append(contentsOf: uniqueFiles)

        for file in uniqueFiles {
            analyze(file)
        }
    }

    private func analyze(_ file: MediaFile) {
        Task {
            await analysisCoordinator.analyze(file)
        }
    }

    private func analyzeAll() {
        for file in files {
            analyze(file)
        }
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
    let analysis: MediaAnalysis?
    let error: String?
    let onAnalyze: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "film")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .lineLimit(1)

                if let analysis {
                    Text(summary(for: analysis))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                } else {
                    Text("Analyse en cours…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if analysis != nil {
                Label("Analysé", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button("Analyser", systemImage: "arrow.clockwise", action: onAnalyze)
                    .labelStyle(.iconOnly)
                    .help("Analyser ce fichier")
            }
        }
        .padding(.vertical, 4)
    }

    private func summary(for analysis: MediaAnalysis) -> String {
        let video = "\(analysis.videoTracks.count) vidéo"
        let audio = "\(analysis.audioTracks.count) audio"
        let subtitles = "\(analysis.subtitleTracks.count) sous-titre\(analysis.subtitleTracks.count == 1 ? "" : "s")"
        return [video, audio, subtitles].joined(separator: " • ")
    }
}

private extension UTType {
    static let mkv = UTType(filenameExtension: "mkv") ?? .data
}
