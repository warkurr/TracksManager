import Foundation

struct TrackMetadataChange: Sendable, Hashable {
    var language: String?
    var title: String?
    var isDefault: Bool?
    var isForced: Bool?
    var isSDH: Bool?

    var isEmpty: Bool {
        language == nil && title == nil && isDefault == nil && isForced == nil && isSDH == nil
    }
}

enum MKVTrackSelector: Sendable, Hashable {
    case trackNumber(Int)
    case uid(Int64)

    var argument: String {
        switch self {
        case .trackNumber(let number): "track:\(number)"
        case .uid(let uid): "track=\(uid)"
        }
    }
}

struct MKVPropEditService: Sendable {
    let runner: ProcessRunner
    let executableURL: URL

    init(runner: ProcessRunner = ProcessRunner(), executableURL: URL) {
        self.runner = runner
        self.executableURL = executableURL
    }

    func edit(fileURL: URL, selector: MKVTrackSelector, change: TrackMetadataChange) async throws -> ProcessResult {
        guard !change.isEmpty else { return ProcessResult(standardOutput: Data(), standardError: Data(), exitCode: 0) }

        var arguments: [String] = ["--abort-on-warnings", fileURL.path, "--edit", selector.argument]
        if let language = change.language { arguments += ["--set", "language=\(language)"] }
        if let title = change.title { arguments += ["--set", "name=\(title)"] }
        if let isDefault = change.isDefault { arguments += ["--set", "flag-default=\(isDefault ? 1 : 0)"] }
        if let isForced = change.isForced { arguments += ["--set", "flag-forced=\(isForced ? 1 : 0)"] }
        if let isSDH = change.isSDH { arguments += ["--set", "flag-hearing-impaired=\(isSDH ? 1 : 0)"] }

        return try await runner.run(executableURL: executableURL, arguments: arguments)
    }
}
