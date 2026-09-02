import SwiftUI
import Observation

@main
struct TracksManagerApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }
        .windowStyle(.automatic)
    }
}

@MainActor
@Observable
final class AppModel {
    var files: [MediaFile] = []
    let analysisCoordinator: AnalysisCoordinator
    let scheduler: JobScheduler

    init(
        analysisCoordinator: AnalysisCoordinator = AnalysisCoordinator(),
        scheduler: JobScheduler = JobScheduler()
    ) {
        self.analysisCoordinator = analysisCoordinator
        self.scheduler = scheduler
    }

    func add(urls: [URL]) {
        let candidates = urls.flatMap { collectMKVs(from: $0) }
        let existing = Set(files.map { $0.url.standardizedFileURL })
        let newFiles = candidates
            .filter { !existing.contains($0.standardizedFileURL) }
            .map { MediaFile(url: $0) }

        files.append(contentsOf: newFiles)
        for file in newFiles {
            Task { await analysisCoordinator.analyze(file) }
        }
    }

    func analyze(_ file: MediaFile, forceRefresh: Bool = false) {
        Task { await analysisCoordinator.analyze(file, forceRefresh: forceRefresh) }
    }

    func analyzeAll() {
        for file in files { analyze(file) }
    }

    func enqueueAll() {
        Task { await scheduler.enqueue(fileURLs: files.map(\.url)) }
    }

    private func collectMKVs(from url: URL) -> [URL] {
        if url.pathExtension.caseInsensitiveCompare("mkv") == .orderedSame { return [url] }
        var results: [URL] = []
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else { return [] }
        for case let child as URL in enumerator {
            guard child.pathExtension.caseInsensitiveCompare("mkv") == .orderedSame else { continue }
            if let values = try? child.resourceValues(forKeys: keys), values.isRegularFile == true {
                results.append(child)
            }
        }
        return results
    }
}
