import Foundation

struct FFProbeAnalyzer: MediaAnalyzer {
    let runner: ProcessRunner
    let executableURL: URL

    init(runner: ProcessRunner = ProcessRunner(), executableURL: URL) {
        self.runner = runner
        self.executableURL = executableURL
    }

    func analyze(fileURL: URL) async throws -> MediaAnalysis {
        let result = try await runner.run(
            executableURL: executableURL,
            arguments: [
                "-v", "error",
                "-show_format",
                "-show_streams",
                "-of", "json",
                fileURL.path
            ]
        )

        let decoder = JSONDecoder()
        let probe = try decoder.decode(FFProbeResponse.self, from: result.standardOutput)

        let videoTracks = probe.streams
            .filter { $0.codecType == "video" }
            .enumerated()
            .map { index, stream in
                VideoTrack(
                    id: stream.index ?? index,
                    codec: stream.codecName,
                    resolution: makeResolution(width: stream.width, height: stream.height),
                    frameRate: stream.frameRate,
                    bitrate: stream.bitRate,
                    hdr: stream.isHDR
                )
            }

        let audioTracks = probe.streams
            .filter { $0.codecType == "audio" }
            .enumerated()
            .map { index, stream in
                AudioTrack(
                    id: stream.index ?? index,
                    codec: stream.codecName,
                    language: stream.tags?.language,
                    title: stream.tags?.title,
                    channels: stream.channels,
                    sampleRate: stream.sampleRate,
                    bitrate: stream.bitRate,
                    isDefault: stream.disposition?.defaultValue == 1,
                    isForced: stream.disposition?.forced == 1,
                    order: index
                )
            }

        let subtitleTracks = probe.streams
            .filter { $0.codecType == "subtitle" }
            .enumerated()
            .map { index, stream in
                SubtitleTrack(
                    id: stream.index ?? index,
                    format: stream.codecName ?? "unknown",
                    language: stream.tags?.language,
                    title: stream.tags?.title,
                    isDefault: stream.disposition?.defaultValue == 1,
                    isForced: stream.disposition?.forced == 1,
                    isSDH: false,
                    order: index,
                    source: .embedded
                )
            }

        return MediaAnalysis(
            fileURL: fileURL,
            duration: probe.format?.duration,
            format: probe.format?.formatName,
            size: probe.format?.size,
            videoTracks: videoTracks,
            audioTracks: audioTracks,
            subtitleTracks: subtitleTracks
        )
    }

    private func makeResolution(width: Int?, height: Int?) -> String? {
        guard let width, let height else { return nil }
        return "\(width) × \(height)"
    }
}

private struct FFProbeResponse: Decodable {
    let streams: [FFProbeStream]
    let format: FFProbeFormat?
}

private struct FFProbeFormat: Decodable {
    let formatName: String?
    let duration: TimeInterval?
    let size: Int64?

    enum CodingKeys: String, CodingKey {
        case formatName = "format_name"
        case duration
        case size
    }
}

private struct FFProbeStream: Decodable {
    let index: Int?
    let codecName: String?
    let codecType: String?
    let width: Int?
    let height: Int?
    let frameRateValue: String?
    let bitRateValue: String?
    let channels: Int?
    let sampleRateValue: String?
    let tags: FFProbeTags?
    let disposition: FFProbeDisposition?

    enum CodingKeys: String, CodingKey {
        case index
        case codecName = "codec_name"
        case codecType = "codec_type"
        case width
        case height
        case frameRateValue = "avg_frame_rate"
        case bitRateValue = "bit_rate"
        case channels
        case sampleRateValue = "sample_rate"
        case tags
        case disposition
    }

    var frameRate: Double? {
        guard let frameRateValue else { return nil }
        let parts = frameRateValue.split(separator: "/")
        guard parts.count == 2,
              let numerator = Double(parts[0]),
              let denominator = Double(parts[1]),
              denominator != 0 else { return Double(frameRateValue) }
        return numerator / denominator
    }

    var bitRate: Int64? {
        bitRateValue.flatMap(Int64.init)
    }

    var sampleRate: Int? {
        sampleRateValue.flatMap { Int(Double($0) ?? 0) }
    }

    var isHDR: Bool {
        false
    }
}

private struct FFProbeTags: Decodable {
    let language: String?
    let title: String?
}

private struct FFProbeDisposition: Decodable {
    let defaultValue: Int
    let forced: Int

    enum CodingKeys: String, CodingKey {
        case defaultValue = "default"
        case forced
    }
}
