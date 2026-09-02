import Foundation

struct ToolLocator: Sendable {
    func executable(named name: String) -> URL? {
        let candidates = [
            Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "Tools"),
            Bundle.main.url(forResource: name, withExtension: nil),
            Bundle.main.privateFrameworksURL?.appendingPathComponent(name)
        ]

        return candidates.compactMap { $0 }.first {
            FileManager.default.isExecutableFile(atPath: $0.path)
        }
    }
}
