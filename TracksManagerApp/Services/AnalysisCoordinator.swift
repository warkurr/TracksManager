import Foundation
import Observation

@MainActor
@Observable
final class AnalysisCoordinator {
    private(set) var analyses: [UUID: MediaAnalysis] = [:]
    private(set) var errors: [UUID: String] = [:]
    private(set) var cachedResults: Set<UUID> = []

    private let locator: ToolLocator
    private let cache: AnalysisCache

    init(locator: ToolLocator = ToolLocator(), cache: AnalysisCache = AnalysisCache()) {
        self.locator = locator
        self.cache = cache
    }

    func analyze(_ file: MediaFile, forceRefresh: Bool = false) async {
        if !forceRefresh, let cached = await cache.cachedAnalysis(for: file.url) {
            analyses[file.id] = cached
            cachedResults.insert(file.id)
            errors.removeValue(forKey: file.id)
            return
        }

        guard let executable = locator.executable(named: "ffprobe") else {
            errors[file.id] = "Le moteur d'analyse intégré n'est pas encore installé dans cette version."
            return
        }

        do {
            let analyzer = FFProbeAnalyzer(executableURL: executable)
            let analysis = try await analyzer.analyze(fileURL: file.url)
            analyses[file.id] = analysis
            cachedResults.remove(file.id)
            errors.removeValue(forKey: file.id)
            await cache.store(analysis)
        } catch {
            errors[file.id] = error.localizedDescription
        }
    }

    func invalidateCache(for file: MediaFile) async {
        await cache.invalidate(fileURL: file.url)
        cachedResults.remove(file.id)
        analyses.removeValue(forKey: file.id)
    }

    func analysis(for file: MediaFile) -> MediaAnalysis? {
        analyses[file.id]
    }

    func error(for file: MediaFile) -> String? {
        errors[file.id]
    }
}
