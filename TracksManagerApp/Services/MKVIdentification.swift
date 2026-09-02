import Foundation

struct MKVIdentification: Codable, Sendable, Hashable {
    let fileName: String
    let tracks: [MKVIdentifiedTrack]
    let warnings: [String]
    let errors: [String]

    var isSupported: Bool { errors.isEmpty }

    func tracks(ofType type: String) -> [MKVIdentifiedTrack] {
        tracks.filter { $0.type.caseInsensitiveCompare(type) == .orderedSame }
    }
}

struct MKVIdentifiedTrack: Codable, Sendable, Hashable, Identifiable {
    let id: Int
    let type: String
    let codec: String
    let properties: [String: JSONValue]

    var trackNumber: Int? { properties["number"]?.intValue }
    var uid: Int64? { properties["uid"]?.int64Value }
    var language: String? { properties["language_ietf"]?.stringValue ?? properties["language"]?.stringValue }
    var title: String? { properties["track_name"]?.stringValue }
    var isDefault: Bool { properties["default_track"]?.boolValue ?? false }
    var isForced: Bool { properties["forced_track"]?.boolValue ?? false }
    var isSDH: Bool { properties["flag_hearing_impaired"]?.boolValue ?? false }
    var isVisualDescriptions: Bool { properties["flag_visual_impaired"]?.boolValue ?? false }
    var isTextDescriptions: Bool { properties["flag_text_descriptions"]?.boolValue ?? false }
    var codecID: String? { properties["codec_id"]?.stringValue }
    var packetizer: String? { properties["packetizer"]?.stringValue }

    /// The stable selector preferred by mkvpropedit when a UID is available.
    var selector: MKVTrackSelector {
        if let uid { return .uid(uid) }
        return .trackNumber(trackNumber ?? id + 1)
    }
}

enum JSONValue: Codable, Sendable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let value = try? container.decode(Bool.self) { self = .bool(value); return }
        if let value = try? container.decode(Double.self) { self = .number(value); return }
        if let value = try? container.decode(String.self) { self = .string(value); return }
        if let value = try? container.decode([String: JSONValue].self) { self = .object(value); return }
        if let value = try? container.decode([JSONValue].self) { self = .array(value); return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    var intValue: Int? {
        switch self {
        case .number(let value): return Int(value)
        case .string(let value): return Int(value)
        default: return nil
        }
    }

    var int64Value: Int64? {
        switch self {
        case .number(let value): return Int64(value)
        case .string(let value): return Int64(value)
        default: return nil
        }
    }
}

struct MKVIdentificationService: Sendable {
    let runner: ProcessRunner
    let executableURL: URL

    init(runner: ProcessRunner = ProcessRunner(), executableURL: URL) {
        self.runner = runner
        self.executableURL = executableURL
    }

    func identify(fileURL: URL) async throws -> MKVIdentification {
        let result = try await runner.run(
            executableURL: executableURL,
            arguments: ["-J", fileURL.path]
        )
        return try JSONDecoder().decode(MKVIdentification.self, from: result.standardOutput)
    }
}
