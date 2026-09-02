import Foundation

struct TrackTargetState: Codable, Hashable, Sendable {
    var language: String?
    var title: String?
    var isDefault: Bool
    var isForced: Bool
    var isSDH: Bool
}

struct TrackChangeSet: Codable, Hashable, Sendable {
    let selector: MKVTrackSelectorCodable
    let before: TrackTargetState
    let after: TrackTargetState

    var metadataChange: TrackMetadataChange {
        TrackMetadataChange(
            language: before.language == after.language ? nil : after.language,
            title: before.title == after.title ? nil : after.title,
            isDefault: before.isDefault == after.isDefault ? nil : after.isDefault,
            isForced: before.isForced == after.isForced ? nil : after.isForced,
            isSDH: before.isSDH == after.isSDH ? nil : after.isSDH
        )
    }

    var changedFields: [String] {
        var fields: [String] = []
        if before.language != after.language { fields.append("Langue") }
        if before.title != after.title { fields.append("Titre") }
        if before.isDefault != after.isDefault { fields.append("Par défaut") }
        if before.isForced != after.isForced { fields.append("Forcé") }
        if before.isSDH != after.isSDH { fields.append("SDH/HI") }
        return fields
    }
}

enum MKVTrackSelectorCodable: Codable, Hashable, Sendable {
    case trackNumber(Int)
    case uid(Int64)

    init(_ selector: MKVTrackSelector) {
        switch selector {
        case .trackNumber(let number): self = .trackNumber(number)
        case .uid(let uid): self = .uid(uid)
        }
    }

    var selector: MKVTrackSelector {
        switch self {
        case .trackNumber(let number): .trackNumber(number)
        case .uid(let uid): .uid(uid)
        }
    }

    var displayValue: String {
        switch self {
        case .trackNumber(let number): "Track \(number)"
        case .uid(let uid): "UID \(uid)"
        }
    }
}

struct TrackPlanBuilder: Sendable {
    func changeSet(selector: MKVTrackSelector, before: TrackTargetState, after: TrackTargetState) -> TrackChangeSet? {
        guard before != after else { return nil }
        return TrackChangeSet(selector: MKVTrackSelectorCodable(selector), before: before, after: after)
    }
}
