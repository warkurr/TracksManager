import Foundation

struct MediaFile: Identifiable, Hashable {
    let id: UUID
    let url: URL
    let analysisStatus: AnalysisStatus

    init(url: URL, analysisStatus: AnalysisStatus = .notAnalyzed) {
        self.id = UUID()
        self.url = url
        self.analysisStatus = analysisStatus
    }

    var name: String { url.lastPathComponent }
}

enum AnalysisStatus: String, Hashable {
    case notAnalyzed
    case analyzing
    case analyzed
    case failed
}

struct VideoTrack: Identifiable, Hashable {
    let id: Int
    var codec: String?
    var resolution: String?
    var frameRate: Double?
    var bitrate: Int64?
    var hdr: Bool
}

struct AudioTrack: Identifiable, Hashable {
    let id: Int
    var codec: String?
    var language: String?
    var title: String?
    var channels: Int?
    var sampleRate: Int?
    var bitrate: Int64?
    var isDefault: Bool
    var isForced: Bool
    var order: Int
}

struct SubtitleTrack: Identifiable, Hashable {
    let id: Int
    var format: String
    var language: String?
    var title: String?
    var isDefault: Bool
    var isForced: Bool
    var isSDH: Bool
    var order: Int
    var source: SubtitleSource
}

enum SubtitleSource: String, Hashable {
    case embedded
    case external
    case downloaded
    case generated
}
