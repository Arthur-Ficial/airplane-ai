import SwiftUI

struct LegalTextView: View {
    let title: String
    let resourceName: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.Padding.large) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(loadText())
                    .font(.callout)
                    .textSelection(.enabled)
            }
            .padding(Metrics.Padding.large * 2)
        }
        .frame(minWidth: 480, idealWidth: 560, minHeight: 400, idealHeight: 600)
    }

    private func loadText() -> String {
        // Search the same bases ModelLocator uses: app bundle, resource bundle, dev tree.
        let candidates: [URL] = [
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/\(resourceName).txt"),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/AirplaneAI_AirplaneAI.bundle/\(resourceName).txt"),
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("AirplaneAI_AirplaneAI.bundle/\(resourceName).txt"),
        ]
        for url in candidates {
            if let text = try? String(contentsOf: url, encoding: .utf8) { return text }
        }
        // Dev fallback: walk up from cwd to find Sources/AirplaneAI/Resources/licenses/.
        var dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<10 {
            let devPath = dir.appendingPathComponent("Sources/AirplaneAI/Resources/licenses/\(resourceName).txt")
            if let text = try? String(contentsOf: devPath, encoding: .utf8) { return text }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { break }
            dir = parent
        }
        return "Unable to load \(title). Please reinstall Airplane AI."
    }
}
