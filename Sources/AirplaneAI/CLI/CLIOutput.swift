import Foundation

public protocol CLIOutput: Sendable {
    func write(_ text: String)
    func writeError(_ text: String)
}

public struct StandardCLIOutput: CLIOutput {
    public init() {}

    public func write(_ text: String) {
        FileHandle.standardOutput.write(Data(text.utf8))
    }

    public func writeError(_ text: String) {
        FileHandle.standardError.write(Data(text.utf8))
    }
}
