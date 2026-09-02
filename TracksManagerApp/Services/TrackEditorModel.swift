import Foundation
import Observation

@MainActor
@Observable
final class TrackEditorModel {
    private(set) var identification: MKVIdentification?
    private(set) var error: String?
    private(set) var isLoading = false

    var selectedTrackID: Int?
    var language = ""
    var title = ""
    var isDefault = false
    var isForced = false
    var isSDH = false

    private let locator: ToolLocator
    private let runner: ProcessRunner

    init(locator: ToolLocator = ToolLocator(), runner: ProcessRunner = ProcessRunner()) {
        self.locator = locator
        self.runner = runner
    }

    func load(fileURL: URL) async {
        guard let executable = locator.executable(named: "mkvmerge") else {
            error = "mkvmerge est introuvable dans l’application."
            return
        }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            identification = try await MKVIdentificationService(runner: runner, executableURL: executable)
            if let selectedTrackID,
               let track = identification?.tracks.first(where: { $0.id == selectedTrackID }) {
                select(track)
            } else if let first = identification?.tracks.first(where: { $0.type == "subtitles" }) {
                select(first)
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func select(_ track: MKVIdentifiedTrack) {
        selectedTrackID = track.id
        language = track.language ?? ""
        title = track.title ?? ""
        isDefault = track.isDefault
        isForced = track.isForced
        isSDH = track.isSDH
    }

    func plan(for track: MKVIdentifiedTrack) -> TrackChangeSet? {
        let before = TrackTargetState(
            language: track.language,
            title: track.title,
            isDefault: track.isDefault,
            isForced: track.isForced,
            isSDH: track.isSDH
        )
        let after = TrackTargetState(
            language: language.nilIfEmpty,
            title: title.nilIfEmpty,
            isDefault: isDefault,
            isForced: isForced,
            isSDH: isSDH
        )
        return TrackPlanBuilder().changeSet(selector: track.selector, before: before, after: after)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
