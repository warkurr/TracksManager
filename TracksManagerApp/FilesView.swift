import SwiftUI
import UniformTypeIdentifiers

struct FilesView: View {
    @Environment(AppModel.self) private var model
    @State private var files: [MediaFile] = []
    @State private var selectedFileID: UUID?
    @State private var isDropTargeted = false
    @State private var showingImporter = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fichiers").font(.largeTitle.bold())
                    Text(files.isEmpty ? "Ajoutez des fichiers MKV ou des dossiers." : "\(files.count) fichier\(files.count == 1 ? "" : "s")")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Analyser tout", systemImage: "waveform.path.ecg") { analyzeAll() }
                    .disabled(files.isEmpty)
                Button("Mettre en file", systemImage: "arrow.right.circle") {
                    Task { await model.scheduler.enqueue(fileURLs: files.map(\.url)) }
                }
                .disabled(files.isEmpty)
                Button("Ajouter", systemImage: "plus") { showingImporter = true }
                    .buttonStyle(.borderedProminent)
            }
            .padding()

            if files.isEmpty {
                ContentUnavailableView {
                    Label("Aucun fichier", systemImage: "film.stack")
                } description: {
                    Text("Glissez-déposez des fichiers MKV ou des dossiers ici pour commencer.")
                } actions: {
                    Button("Choisir des fichiers") { showingImporter = true }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(isDropTargeted ? Color.accentColor.opacity(0.08) : .clear)
            } else {
                HSplitView {
                    List(selection: $selectedFileID) {
                        ForEach(files) { file in
                            FileRow(
                                file: file,
                                analysis: model.analysisCoordinator.analysis(for: file),
                                error: model.analysisCoordinator.error(for: file),
                                isCached: model.analysisCoordinator.cachedResults.contains(file.id),
                                onAnalyze: { model.analyze(file, forceRefresh: true) }
                            )
                            .tag(file.id)
                        }
                    }
                    .listStyle(.inset)
                    .frame(minWidth: 360, idealWidth: 430)

                    FileDetailView(
                        file: selectedFile,
                        analysis: selectedFile.flatMap { model.analysisCoordinator.analysis(for: $0) },
                        error: selectedFile.flatMap { model.analysisCoordinator.error(for: $0) },
                        onAnalyze: { if let selectedFile { model.analyze(selectedFile, forceRefresh: true) } }
                    )
                    .frame(minWidth: 480)
                }
            }
        }
        .onChange(of: files) { _, newFiles in
            if selectedFileID == nil { selectedFileID = newFiles.first?.id }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            Task { await importDroppedFiles(from: providers) }
            return true
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.mkv, .folder], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            add(urls: urls)
        }
    }

    private var selectedFile: MediaFile? {
        guard let selectedFileID else { return nil }
        return files.first(where: { $0.id == selectedFileID })
    }

    private func add(urls: [URL]) {
        let candidates = urls.flatMap { collectMKVs(from: $0) }
        let existing = Set(files.map { $0.url.standardizedFileURL })
        let newFiles = candidates.filter { !existing.contains($0.standardizedFileURL) }.map { MediaFile(url: $0) }
        files.append(contentsOf: newFiles)
        if selectedFileID == nil { selectedFileID = newFiles.first?.id }
        for file in newFiles { model.analyze(file) }
    }

    private func collectMKVs(from url: URL) -> [URL] {
        if url.pathExtension.caseInsensitiveCompare("mkv") == .orderedSame { return [url] }
        var results: [URL] = []
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]) else { return [] }
        for case let child as URL in enumerator {
            guard child.pathExtension.caseInsensitiveCompare("mkv") == .orderedSame else { continue }
            if let values = try? child.resourceValues(forKeys: keys), values.isRegularFile == true { results.append(child) }
        }
        return results
    }

    private func analyzeAll() { model.analyzeAll() }

    private func importDroppedFiles(from providers: [NSItemProvider]) async {
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            do {
                let item = try await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier)
                guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { continue }
                await MainActor.run { add(urls: [url]) }
            } catch { }
        }
    }
}

private struct FileRow: View {
    let file: MediaFile
    let analysis: MediaAnalysis?
    let error: String?
    let isCached: Bool
    let onAnalyze: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "film").font(.title3).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name).lineLimit(1)
                if let analysis {
                    Text(summary(for: analysis)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                } else if let error {
                    Text(error).font(.caption).foregroundStyle(.red).lineLimit(2)
                } else {
                    Text("Analyse en cours…").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if analysis != nil {
                Label(isCached ? "Cache" : "Analysé", systemImage: isCached ? "internaldrive" : "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Button("Analyser", systemImage: "arrow.clockwise", action: onAnalyze).labelStyle(.iconOnly).help("Analyser ce fichier")
            }
        }
        .padding(.vertical, 4)
    }

    private func summary(for analysis: MediaAnalysis) -> String {
        "\(analysis.videoTracks.count) vidéo • \(analysis.audioTracks.count) audio • \(analysis.subtitleTracks.count) sous-titre\(analysis.subtitleTracks.count == 1 ? "" : "s")"
    }
}

private struct FileDetailView: View {
    let file: MediaFile?
    let analysis: MediaAnalysis?
    let error: String?
    let onAnalyze: () -> Void

    var body: some View {
        Group {
            if let file {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(file.name).font(.title2.bold()).textSelection(.enabled)
                            Text(file.url.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                        if let analysis {
                            OverviewSection(analysis: analysis)
                            TrackSection(title: "Vidéo", systemImage: "rectangle.on.rectangle") { ForEach(analysis.videoTracks) { VideoTrackRow(track: $0) } }
                            TrackSection(title: "Audio", systemImage: "waveform") { ForEach(analysis.audioTracks) { AudioTrackRow(track: $0) } }
                            TrackSection(title: "Sous-titres", systemImage: "captions.bubble") { ForEach(analysis.subtitleTracks) { SubtitleTrackRow(track: $0) } }
                        } else if let error {
                            ContentUnavailableView { Label("Analyse impossible", systemImage: "exclamationmark.triangle") } description: { Text(error) } actions: { Button("Réessayer", action: onAnalyze) }
                        } else {
                            ProgressView("Analyse en cours…").frame(maxWidth: .infinity, minHeight: 260)
                        }
                    }
                    .padding(24)
                }
            } else {
                ContentUnavailableView("Sélectionnez un fichier", systemImage: "sidebar.left")
            }
        }
    }
}

private struct OverviewSection: View {
    let analysis: MediaAnalysis
    var body: some View {
        GroupBox("Résumé") {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)], alignment: .leading, spacing: 14) {
                Metric(title: "Durée", value: formattedDuration(analysis.duration))
                Metric(title: "Taille", value: formattedBytes(analysis.size))
                Metric(title: "Conteneur", value: analysis.format?.uppercased() ?? "Inconnu")
                Metric(title: "Vidéo", value: "\(analysis.videoTracks.count)")
                Metric(title: "Audio", value: "\(analysis.audioTracks.count)")
                Metric(title: "Sous-titres", value: "\(analysis.subtitleTracks.count)")
            }.padding(6)
        }
    }
}

private struct Metric: View {
    let title: String; let value: String
    var body: some View { VStack(alignment: .leading, spacing: 3) { Text(title).font(.caption).foregroundStyle(.secondary); Text(value).font(.headline) } }
}

private struct TrackSection<Content: View>: View {
    let title: String; let systemImage: String; @ViewBuilder let content: Content
    var body: some View {
        GroupBox { VStack(alignment: .leading, spacing: 0) { HStack { Label(title, systemImage: systemImage).font(.headline); Spacer() }; Divider().padding(.vertical, 8); content }.padding(6) }
    }
}

private struct VideoTrackRow: View {
    let track: VideoTrack
    var body: some View {
        HStack { VStack(alignment: .leading, spacing: 4) { Text("Piste \(track.id + 1)").font(.body.weight(.medium)); Text([track.displayCodec, track.displayResolution, track.displayFrameRate].joined(separator: " • ")).font(.caption).foregroundStyle(.secondary) }; Spacer(); if track.hdr { Text("HDR").font(.caption.weight(.semibold)).padding(.horizontal, 7).padding(.vertical, 3).background(.secondary.opacity(0.12), in: Capsule()) } }.padding(.vertical, 6)
    }
}

private struct AudioTrackRow: View {
    let track: AudioTrack
    var body: some View {
        HStack { VStack(alignment: .leading, spacing: 4) { Text(track.displayTitle).font(.body.weight(.medium)); Text([track.displayLanguage, track.codec?.uppercased() ?? "Codec inconnu", track.displayChannels].joined(separator: " • ")).font(.caption).foregroundStyle(.secondary) }; Spacer(); TrackBadges(isDefault: track.isDefault, isForced: track.isForced, isSDH: false) }.padding(.vertical, 6)
    }
}

private struct SubtitleTrackRow: View {
    let track: SubtitleTrack
    var body: some View {
        HStack { VStack(alignment: .leading, spacing: 4) { Text(track.displayTitle).font(.body.weight(.medium)); Text([track.displayLanguage, track.displayFormat].joined(separator: " • ")).font(.caption).foregroundStyle(.secondary) }; Spacer(); TrackBadges(isDefault: track.isDefault, isForced: track.isForced, isSDH: track.isSDH) }.padding(.vertical, 6)
    }
}

private struct TrackBadges: View {
    let isDefault: Bool; let isForced: Bool; let isSDH: Bool
    var body: some View { HStack(spacing: 5) { if isDefault { Badge("Default") }; if isForced { Badge("Forced") }; if isSDH { Badge("SDH") } } }
    private func Badge(_ text: String) -> some View { Text(text).font(.caption2.weight(.semibold)).padding(.horizontal, 6).padding(.vertical, 3).background(.secondary.opacity(0.12), in: Capsule()) }
}

private func formattedDuration(_ duration: TimeInterval?) -> String {
    guard let duration else { return "Inconnue" }
    let totalSeconds = max(0, Int(duration.rounded())); let hours = totalSeconds / 3600; let minutes = (totalSeconds % 3600) / 60; let seconds = totalSeconds % 60
    return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, seconds) : String(format: "%d:%02d", minutes, seconds)
}

private func formattedBytes(_ size: Int64?) -> String {
    guard let size else { return "Inconnue" }
    return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
}

private extension UTType {
    static let mkv = UTType(filenameExtension: "mkv") ?? .data
}
