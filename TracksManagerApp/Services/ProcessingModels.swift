import Foundation

enum ProcessingState: String, Codable, Hashable, Sendable {
    case waiting
    case analyzing
    case planning
    case processing
    case validating
    case completed
    case failed
    case skipped
    case cancelled
    case warning
}

enum ProcessingOperationKind: String, Codable, Hashable, Sendable {
    case analyze
    case extractSubtitle
    case convertSubtitle
    case synchronizeSubtitle
    case addTrack
    case removeTrack
    case modifyTrack
    case replaceTrack
    case export
    case validate
}

struct ProcessingOperation: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let kind: ProcessingOperationKind
    let title: String
    let detail: String
    let destructive: Bool

    init(id: UUID = UUID(), kind: ProcessingOperationKind, title: String, detail: String, destructive: Bool = false) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.destructive = destructive
    }
}

struct ProcessingPlan: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let fileURL: URL
    let operations: [ProcessingOperation]
    let requiresBackup: Bool

    init(id: UUID = UUID(), fileURL: URL, operations: [ProcessingOperation], requiresBackup: Bool = false) {
        self.id = id
        self.fileURL = fileURL
        self.operations = operations
        self.requiresBackup = requiresBackup
    }

    var isEmpty: Bool { operations.isEmpty }
}

struct ProcessingJob: Identifiable, Hashable, Sendable {
    let id: UUID
    let fileURL: URL
    var state: ProcessingState
    var progress: Double
    var currentOperation: String?
    var errorMessage: String?
    var plan: ProcessingPlan?

    init(id: UUID = UUID(), fileURL: URL, state: ProcessingState = .waiting, progress: Double = 0, currentOperation: String? = nil, errorMessage: String? = nil, plan: ProcessingPlan? = nil) {
        self.id = id
        self.fileURL = fileURL
        self.state = state
        self.progress = progress
        self.currentOperation = currentOperation
        self.errorMessage = errorMessage
        self.plan = plan
    }
}
