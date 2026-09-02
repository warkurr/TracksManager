import Foundation

actor JobScheduler {
    enum ConcurrencyMode: Sendable, Hashable {
        case automatic
        case manual(Int)
        case economy

        var limit: Int {
            switch self {
            case .automatic:
                max(1, ProcessInfo.processInfo.activeProcessorCount - 1)
            case .manual(let value):
                min(max(1, value), 20)
            case .economy:
                1
            }
        }
    }

    private(set) var jobs: [UUID: ProcessingJob] = [:]
    private var pending: [UUID] = []
    private var running = 0
    private var mode: ConcurrencyMode = .automatic

    func setConcurrencyMode(_ mode: ConcurrencyMode) {
        self.mode = mode
        pump()
    }

    func enqueue(fileURLs: [URL]) {
        for url in fileURLs {
            let job = ProcessingJob(fileURL: url)
            jobs[job.id] = job
            pending.append(job.id)
        }
        pump()
    }

    func cancel(jobID: UUID) {
        guard var job = jobs[jobID] else { return }
        guard job.state == .waiting else { return }
        job.state = .cancelled
        jobs[jobID] = job
        pending.removeAll { $0 == jobID }
    }

    func cancelAllWaiting() {
        for id in pending { cancel(jobID: id) }
    }

    func snapshot() -> [ProcessingJob] {
        jobs.values.sorted { lhs, rhs in
            if lhs.state == rhs.state { return lhs.fileURL.lastPathComponent < rhs.fileURL.lastPathComponent }
            return lhs.state.rawValue < rhs.state.rawValue
        }
    }

    private func pump() {
        while running < mode.limit, let next = pending.first {
            pending.removeFirst()
            guard var job = jobs[next], job.state == .waiting else { continue }
            job.state = .planning
            job.progress = 0
            jobs[next] = job
            running += 1
            Task { [next] in await finishPlanning(jobID: next) }
        }
    }

    private func finishPlanning(jobID: UUID) async {
        guard var job = jobs[jobID] else { return }
        let builder = ProcessingPlanBuilder()
        job.plan = builder.makeValidationPlan(for: MediaFile(url: job.fileURL))
        job.progress = 0.1
        job.currentOperation = job.plan?.operations.first?.title
        job.state = .waiting
        jobs[jobID] = job
        running -= 1
        pump()
    }
}
