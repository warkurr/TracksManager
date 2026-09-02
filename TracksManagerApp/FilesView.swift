import SwiftUI
import UniformTypeIdentifiers

struct FilesView: View {
    @Environment(AppModel.self) private var model
    @State private var selectedFileID: UUID?
    @State private var isDropTargeted = false
    @State private var showingImporter = false
    @State private var editor = TrackEditorModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fichiers").font(.largeTitle.bold())
                    Text(model.files.isEmpty ? "Ajoutez des fichiers MKV ou des dossiers." : "\(model.files.count) fichier\(model.files.count == 1 ? "" : "s")")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Analyser tout", systemImage: "waveform.path.ecg") { model.analyzeAll() }
                    .disabled(model.files.isEmpty)
                Button("Mettre en file", systemImage: "arrow.right.circle") { model.enqueueAll() }
                    .disabled(model.files.isEmpty)
                Button("Ajouter", systemImage: "plus") { showingImporter = true }
                    .buttonStyle(.borderedProminent)
            }
            .padding()

            if model.files.isEmpty {
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
                        ForEach(model.files) { file in
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
                        editor: editor,
                        onAnalyze: { if let selectedFile { model.analyze(selectedFile, forceRefresh: true) } }
                    )
                    .frame(minWidth: 520)
                }
            }
        }
        .task(id: selectedFileID) {
            if let file = selectedFile { await editor.load(fileURL: file.url) }
        }
        .onChange(of: model.files) { _, newFiles in
            if selectedFileID == nil { selectedFileID = newFiles.first?.id }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            Task { await importDroppedFiles(from: providers) }
            return true
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.mkv, .folder], allowsMultipleSelection: true) { result in
            guard case .success(let urls) = result else { return }
            model.add(urls: urls)
        }
    }

    private var selectedFile: MediaFile? {
        guard let selectedFileID else { return nil }
        return model.files.first(where: { $0.id == selectedFileID })
    }

    private func importDroppedFiles(from providers: [NSItemProvider]) async {
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            do {
                let item = try await provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier)
                guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { continue }
                await MainActor.run { model.add(urls: [url]) }
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
    @Bindable var editor: TrackEditorModel
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
                            TrackSection(title: "Vidéo", systemImage: "rectangle.on.rectangle") {
                                ForEach(analysis.videoTracks) { VideoTrackRow(track: $0) }
                            }
                            TrackSection(title: "Audio", systemImage: "waveform") {
                                ForEach(analysis.audioTracks) { AudioTrackRow(track: $0) }
                            }
                            TrackSection(title: "Sous-titres", systemImage: "captions.bubble") {
                                ForEach(editor.identification?.tracks.filter { $0.type == "subtitles" } ?? []) { track in
                                    SubtitleEditorRow(track: track, editor: editor)
                                }
                            }
                        } else if let error {
                            ContentUnavailableView {
                                Label("Analyse impossible", systemImage: "exclamationmark.triangle")
                            } description: {
                                Text(error)
                            } actions: {
                                Button("Réessayer", action: onAnalyze)
                            }
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

private struct SubtitleEditorRow: View {
    let track: MKVIdentifiedTrack
    @Bindable var editor: TrackEditorModel
    @State private var showPlan = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title ?? track.language ?? "Sous-titre \(track.id + 1)").font(.body.weight(.medium))
                    Text("ID \(track.id) • \(track.codec)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if editor.selectedTrackID == track.id {
                    Text("Sélectionné").font(.caption).foregroundStyle(.secondary)
                }
            }
            Button("Modifier", systemImage: "pencil") { editor.select(track) }
                .buttonStyle(.borderless)

            if editor.selectedTrackID == track.id {
                Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                    GridRow {
                        Text("Langue").foregroundStyle(.secondary)
                        TextField("fr", text: $editor.language).textFieldStyle(.roundedBorder)
                    }
                    GridRow {
                        Text("Titre").foregroundStyle(.secondary)
                        TextField("Titre de piste", text: $editor.title).textFieldStyle(.roundedBorder)
                    }
                }
                Toggle("Par défaut", isOn: $editor.isDefault)
                Toggle("Forcé", isOn: $editor.isForced)
                Toggle("SDH / HI", isOn: $editor.isSDH)

                if let plan = editor.plan(for: track) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Avant → Après").font(.subheadline.bold())
                        Text(plan.changedFields.joined(separator: " • ")).font(.caption).foregroundStyle(.secondary)
                        Button("Voir le plan", action: { showPlan = true })
                    }
                    .padding(10)
                    .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
                    .sheet(isPresented: $showPlan) {
                        TrackPlanSheet(plan: plan, fileName: "")
                    }
                } else {
                    Text("Aucune modification en attente.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct TrackPlanSheet: View {
    let plan: TrackChangeSet
    let fileName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Plan de modification").font(.title2.bold())
            if !fileName.isEmpty { Text(fileName).foregroundStyle(.secondary) }
            ForEach(plan.changedFields, id: \.self) { field in
                Text(field).font(.headline)
            }
            HStack {
                Text("Sélecteur").foregroundStyle(.secondary)
                Spacer()
                Text(plan.selector.displayValue).monospaced()
            }
            Spacer()
        }
        .padding(24)
        .frame(minWidth: 360, minHeight: 240)
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
    let title: String
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline)
        }
    }
}

private struct TrackSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 0) {
                HStack { Label(title, systemImage: systemImage).font(.headline); Spacer() }
                Divider().padding(.vertical, 8)
                content
            }.padding(6)
        }
    }
}

private struct VideoTrackRow: View {
    let track: VideoTrack
    var body: some View {
        LabeledContent("Codec", value: track.displayCodec)
        LabeledContent("Résolution", value: track.displayResolution)
        LabeledContent("FPS", value: track.displayFrameRate)
    }
}

private struct AudioTrackRow: View {
    let track: AudioTrack
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(track.displayTitle)
                Spacer()
                if track.isDefault { Label("Défaut", systemImage: "checkmark.circle") }
                if track.isForced { Label("Forcé", systemImage: "exclamationmark.circle") }
            }
            Text("\(track.displayLanguage) • \(track.displayChannels)").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
    }
}

private func formattedDuration(_ duration: TimeInterval?) -> String {
    guard let duration else { return "Inconnue" }
    let total = Int(duration.rounded())
    return String(format: "%02d:%02d:%02d", total / 3600, (total / 60) % 60, total % 60)
}

private func formattedBytes(_ size: Int64?) -> String {
    guard let size else { return "Inconnue" }
    return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
}
