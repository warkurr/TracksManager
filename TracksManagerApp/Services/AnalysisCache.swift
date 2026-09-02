import Foundation

struct CachedMediaAnalysis: Codable, Sendable {
    let fileSize: Int64
    let modificationDate: Date
    let analysis: MediaAnalysis
}

actor AnalysisCache {
    private var memory: [URL: CachedMediaAnalysis] = [:]
    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        directory = base.appendingPathComponent("TracksManager/Analysis", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func cachedAnalysis(for fileURL: URL) -> MediaAnalysis? {
        guard let fingerprint = fingerprint(for: fileURL) else { return nil }

        if let cached = memory[fileURL], isValid(cached, fingerprint: fingerprint) {
            return cached.analysis
        }

        guard let data = try? Data(contentsOf: cacheURL(for: fileURL)),
              let cached = try? decoder.decode(CachedMediaAnalysis.self, from: data),
              isValid(cached, fingerprint: fingerprint) else {
            return nil
        }

        memory[fileURL] = cached
        return cached.analysis
    }

    func store(_ analysis: MediaAnalysis) {
        guard let fingerprint = fingerprint(for: analysis.fileURL) else { return }

        let cached = CachedMediaAnalysis(
            fileSize: fingerprint.size,
            modificationDate: fingerprint.modificationDate,
            analysis: analysis
        )

        memory[analysis.fileURL] = cached
        guard let data = try? encoder.encode(cached) else { return }
        try? data.write(to: cacheURL(for: analysis.fileURL), options: .atomic)
    }

    func invalidate(fileURL: URL) {
        memory.removeValue(forKey: fileURL)
        try? FileManager.default.removeItem(at: cacheURL(for: fileURL))
    }

    private func isValid(_ cached: CachedMediaAnalysis, fingerprint: FileFingerprint) -> Bool {
        cached.fileSize == fingerprint.size && cached.modificationDate == fingerprint.modificationDate
    }

    private func fingerprint(for fileURL: URL) -> FileFingerprint? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attributes[.size] as? NSNumber,
              let modificationDate = attributes[.modificationDate] as? Date else {
            return nil
        }
        return FileFingerprint(size: size.int64Value, modificationDate: modificationDate)
    }

    private func cacheURL(for fileURL: URL) -> URL {
        let key = Data(fileURL.standardizedFileURL.path.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        return directory.appendingPathComponent("\(key).json")
    }
}

private struct FileFingerprint: Sendable {
    let size: Int64
    let modificationDate: Date
}
