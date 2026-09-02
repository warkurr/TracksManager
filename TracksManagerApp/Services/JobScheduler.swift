import Foundation

actor JobScheduler {
    enum ConcurrencyMode: Sendable, Hashable {
        case automatic
        case manual(Int)
        case economy

        var limit: Int {
            switch self {
            case .automatic:
                max(1, min(8, ProcessInfo.processInfo.activeProcessorCount - 1))
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
    private var tasks: [UUID: Task<Void, Never>] = [:]

    func setConcurrencyMode(_ mode: ConcurrencyMode) {
        self.mode = mode
        pump()
    }

    func enqueue(fileURLs: [URL]) {
        let existing = Set(jobs.values.map { $0.fileURL.standardizedFileURL })
        for url in fileURLs where FileManager.default.fileExists(atPath: url.path) && !existing.contains(url.standardizedFileURL) {
            let job = ProcessingJob(fileURL: url)
            jobs[job.id] = job
            pending.append(job.id)
        }
        pump()
    }

    func cancel(jobID: UUID) {
        if let task = tasks[jobID] {
            task.cancel()
            return
        }
        guard var job = jobs[jobID], job.state == .waiting || job.state == .planning else { return }
        job.state = .cancelled
        job.progress = 1
        job.currentOperation = nil
        jobs[jobID] = job
        pending.removeAll { $0 == jobID }
    }

    func cancelAllWaiting() {
        for id in pending { cancel(jobID: id) }
    }

    func snapshot() -> [ProcessingJob] {
        jobs.values.sorted {
            if $0.state == $1.state {
                return $0.fileURL.lastPathComponent.localizedStandardCompare($1.fileURL.lastPathComponent) == .orderedAscending
            }
            return stateOrder($0.state) < stateOrder($1.state)
        }
    }

    func clearFinished() {
        let removable = jobs.values.filter {
            switch $0.state {
            case .completed, .failed, .skipped, .cancelled, .warning: true
            default: false
            }
        }.map(\.id)
        for id in removable { jobs.removeValue(forKey: id) }
    }

    private func pump() {
        while running < mode.limit, let next = pending.first {
            pending.removeFirst()
            guard var job = jobs[next], job.state == .waiting else { continue }
            job.state = .planning
            job.progress = 0
            job.errorMessage = nil
            jobs[next] = job
            running += 1
            let task = Task { [next] in
                await self.execute(jobID: next)
            }
            tasks[next] = task
        }
    }

    private func execute(jobID: UUID) async {
        defer {
            tasks.removeValue(forKey: jobID)
            running = max(0, running - 1)
            pump()
        }

        guard var job = jobs[jobID] else { return }
        let builder = ProcessingPlanBuilder()
        let plan = builder.makeValidationPlan(for: MediaFile(url: job.fileURL))
        job.plan = plan
        job.currentOperation = plan.operations.first?.title
        job.progress = 0.05
        jobs[jobID] = job

        do {
            try Task.checkCancellation()
            guard FileManager.default.fileExists(atPath: job.fileURL.path) else {
                throw JobSchedulerError.fileMissing(job.fileURL.lastPathComponent)
            }

            guard let executable = ToolLocator().executable(named: "mkvmerge") else {
                throw JobSchedulerError.toolMissing("mkvmerge")
            }

            job.state = .processing
            job.progress = 0.2
            jobs[jobID] = job

            let result = try await ProcessRunner().run(
                executableURL: executable,
                arguments: ["-J", job.fileURL.path]
            )
            try Task.checkCancellation()
            guard !result.standardOutput.isEmpty else {
                throw JobSchedulerError.invalidOutput
            }
            _ = try JSONDecoder().decode(MKVIdentification.self, from: result.standardOutput)

            job.state = .validating
            job.progress = 0.85
            jobs[jobID] = job

            // A successful mkvmerge identification is the first real integrity check.
            // A later processing operation can add stronger before/after assertions.
            job.state = .completed
            job.progress = 1
            job.currentOperation = nil
            jobs[jobID] = job
        } catch is CancellationError {
            job.state = .cancelled
            job.progress = 1
            job.currentOperation = nil
            jobs[jobID] = job
        } catch {
            job.state = .failed
            job.progress = 1
            job.currentOperation = nil
            job.errorMessage = error.localizedDescription
            jobs[jobID] = job
        }
    }

    private func stateOrder(_ state: ProcessingState) -> Int {
        switch state {
        case .processing, .analyzing, .planning, .validating: 0
        case .waiting: 1
        case .warning: 2
        case .failed: 3
        case .cancelled: 4
        case .completed: 5
        case .skipped: 6
        }
    }
}

enum JobSchedulerError: LocalizedError {
    case fileMissing(String)
    case toolMissing(String)
    case invalidOutput

    var errorDescription: String? {
        switch self {
        case .fileMissing(let name):
            return "Le fichier n’est plus accessible : \(name)"
        case .toolMissing(let name):
            return "L’outil intégré \(name) est indisponible."
        case .invalidOutput:
            return "Le moteur MKV n’a pas renvoyé une identification valide."
        }
    }
}
