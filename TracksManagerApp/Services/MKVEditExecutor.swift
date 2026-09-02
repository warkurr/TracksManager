import Foundation

enum MKVEditError: LocalizedError {
    case noExecutable
    case noChanges
    case backupFailed(String)
    case invalidFile

    var errorDescription: String? {
        switch self {
        case .noExecutable: "mkvpropedit est introuvable dans l’application."
        case .noChanges: "Aucune modification à appliquer."
        case .backupFailed(let reason): "Impossible de créer la sauvegarde : \(reason)"
        case .invalidFile: "Le fichier MKV n’est plus accessible."
        }
    }
}

enum FileModificationMode: String, Codable, Sendable, CaseIterable {
    case copy
    case modifyOriginal
    case backupThenModify

    var displayName: String {
        switch self {
        case .copy: "Créer une copie"
        case .modifyOriginal: "Modifier l’original"
        case .backupThenModify: "Sauvegarder puis modifier"
        }
    }
}

struct MKVEditExecutor: Sendable {
    let locator: ToolLocator
    let runner: ProcessRunner

    init(locator: ToolLocator = ToolLocator(), runner: ProcessRunner = ProcessRunner()) {
        self.locator = locator
        self.runner = runner
    }

    func applyMetadataChanges(
        to fileURL: URL,
        changes: [(selector: MKVTrackSelector, change: TrackMetadataChange)],
        mode: FileModificationMode
    ) async throws -> URL {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { throw MKVEditError.invalidFile }
        guard !changes.isEmpty, changes.contains(where: { !$0.change.isEmpty }) else { throw MKVEditError.noChanges }
        guard let executable = locator.executable(named: "mkvpropedit") else { throw MKVEditError.noExecutable }

        let targetURL: URL
        switch mode {
        case .copy:
            let base = fileURL.deletingPathExtension()
            targetURL = base.appendingPathExtension("tracksmanager.mkv")
            try FileManager.default.copyItem(at: fileURL, to: targetURL)
        case .modifyOriginal, .backupThenModify:
            targetURL = fileURL
        }

        if mode == .backupThenModify {
            let backup = fileURL.appendingPathExtension("tracksmanager-backup.mkv")
            do { try FileManager.default.copyItem(at: fileURL, to: backup) }
            catch { throw MKVEditError.backupFailed(error.localizedDescription) }
        }

        for item in changes where !item.change.isEmpty {
            _ = try await MKVPropEditService(runner: runner, executableURL: executable)
                .edit(fileURL: targetURL, selector: item.selector, change: item.change)
        }
        return targetURL
    }
}
