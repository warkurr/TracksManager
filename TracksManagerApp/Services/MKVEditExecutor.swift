import Foundation

enum MKVEditError: LocalizedError {
    case noExecutable
    case noChanges
    case backupFailed(String)
    case copyFailed(String)
    case invalidFile

    var errorDescription: String? {
        switch self {
        case .noExecutable: "mkvpropedit est introuvable dans l’application."
        case .noChanges: "Aucune modification à appliquer."
        case .backupFailed(let reason): "Impossible de créer la sauvegarde : \(reason)"
        case .copyFailed(let reason): "Impossible de créer la copie de travail : \(reason)"
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
        let effectiveChanges = changes.filter { !$0.change.isEmpty }
        guard !effectiveChanges.isEmpty else { throw MKVEditError.noChanges }
        guard let executable = locator.executable(named: "mkvpropedit") else { throw MKVEditError.noExecutable }

        let fileManager = FileManager.default
        let targetURL: URL
        var backupURL: URL?

        switch mode {
        case .copy:
            targetURL = uniqueSiblingURL(for: fileURL, suffix: ".tracksmanager", pathExtension: "mkv")
            do { try fileManager.copyItem(at: fileURL, to: targetURL) }
            catch { throw MKVEditError.copyFailed(error.localizedDescription) }
        case .modifyOriginal:
            targetURL = fileURL
        case .backupThenModify:
            targetURL = fileURL
            let backup = uniqueSiblingURL(for: fileURL, suffix: ".tracksmanager-backup", pathExtension: "mkv")
            do {
                try fileManager.copyItem(at: fileURL, to: backup)
                backupURL = backup
            } catch {
                throw MKVEditError.backupFailed(error.localizedDescription)
            }
        }

        var arguments = ["--abort-on-warnings", targetURL.path]
        for item in effectiveChanges {
            arguments += ["--edit", item.selector.argument]
            if let language = item.change.language { arguments += ["--set", "language=\(language)"] }
            if let title = item.change.title { arguments += ["--set", "name=\(title)"] }
            if let isDefault = item.change.isDefault { arguments += ["--set", "flag-default=\(isDefault ? 1 : 0)"] }
            if let isForced = item.change.isForced { arguments += ["--set", "flag-forced=\(isForced ? 1 : 0)"] }
            if let isSDH = item.change.isSDH { arguments += ["--set", "flag-hearing-impaired=\(isSDH ? 1 : 0)"] }
        }

        do {
            _ = try await runner.run(executableURL: executable, arguments: arguments)
            return targetURL
        } catch {
            if mode == .copy {
                try? fileManager.removeItem(at: targetURL)
            } else if let backupURL {
                do {
                    try fileManager.removeItem(at: targetURL)
                    try fileManager.copyItem(at: backupURL, to: targetURL)
                } catch {
                    throw MKVEditError.backupFailed("La modification a échoué et la restauration automatique a également échoué : \(error.localizedDescription)")
                }
            }
            throw error
        }
    }

    private func uniqueSiblingURL(for fileURL: URL, suffix: String, pathExtension: String) -> URL {
        let directory = fileURL.deletingLastPathComponent()
        let stem = fileURL.deletingPathExtension().lastPathComponent
        let base = directory.appendingPathComponent("\(stem)\(suffix)").appendingPathExtension(pathExtension)
        if !FileManager.default.fileExists(atPath: base.path) { return base }

        for index in 2...9999 {
            let candidate = directory
                .appendingPathComponent("\(stem)\(suffix)-\(index)")
                .appendingPathExtension(pathExtension)
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        return directory
            .appendingPathComponent("\(stem)\(suffix)-\(UUID().uuidString)")
            .appendingPathExtension(pathExtension)
    }
}
