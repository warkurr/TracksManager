import Foundation
import Observation

@MainActor
@Observable
final class AnalysisCoordinator {
    private(set) var analyses: [UUID: MediaAnalysis] = [:]
    private(set) var errors: [UUID: String] = [:]

    private let locator: ToolLocator

    init(locator: ToolLocator = ToolLocator()) {
        self.locator = locator
    }

    func analyze(_ file: MediaFile) async {
        guard let executable = locator.executable(named: "ffprobe") else {
            errors[file.id] = "Le moteur d'analyse intégré n'est pas encore installé dans cette version."
            return
        }

        do {
            let analyzer = FFProbeAnalyzer(executableURL: executable)
            analyses[file.id] = try await analyzer.analyze(fileURL: file.url)
            errors.removeValue(forKey: file.id)
        } catch {
            errors[file.id] = error.localizedDescription
        }
    }

    func analysis(for file: MediaFile) -> MediaAnalysis? {
        analyses[file.id]
    }

    func error(for file: MediaFile) -> String? {
        errors[file.id]
    }
}
