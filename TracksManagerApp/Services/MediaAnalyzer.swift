import Foundation

protocol MediaAnalyzer: Sendable {
    func analyze(fileURL: URL) async throws -> MediaAnalysis
}

struct MediaAnalysis: Codable, Sendable, Hashable {
    let fileURL: URL
    let duration: TimeInterval?
    let format: String?
    let size: Int64?
    let videoTracks: [VideoTrack]
    let audioTracks: [AudioTrack]
    let subtitleTracks: [SubtitleTrack]
}

enum MediaAnalyzerError: LocalizedError {
    case unsupportedFile(URL)
    case noAnalyzerAvailable
    case invalidAnalyzerOutput

    var errorDescription: String? {
        switch self {
        case .unsupportedFile(let url):
            return "Le fichier n'est pas un MKV pris en charge : \(url.lastPathComponent)"
        case .noAnalyzerAvailable:
            return "Aucun moteur d'analyse MKV intégré n'est actuellement disponible."
        case .invalidAnalyzerOutput:
            return "Le moteur d'analyse a renvoyé des données invalides."
        }
    }
}

struct UnavailableMediaAnalyzer: MediaAnalyzer {
    func analyze(fileURL: URL) async throws -> MediaAnalysis {
        guard fileURL.pathExtension.caseInsensitiveCompare("mkv") == .orderedSame else {
            throw MediaAnalyzerError.unsupportedFile(fileURL)
        }
        throw MediaAnalyzerError.noAnalyzerAvailable
    }
}
