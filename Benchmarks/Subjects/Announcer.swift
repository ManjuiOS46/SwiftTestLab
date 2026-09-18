import Foundation

/// Deliberately has no observable behaviour: everything it does goes to stdout.
public struct Announcer {
    private let prefix: String

    public init(prefix: String) {
        self.prefix = prefix
    }

    public func announce(_ message: String) {
        print("\(prefix): \(message)")
    }

    public func warn(_ message: String) {
        print("\(prefix) WARNING: \(message)")
    }
}
