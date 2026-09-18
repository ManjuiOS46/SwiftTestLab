import Foundation

public struct Version: Equatable, Comparable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public static func < (lhs: Version, rhs: Version) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}

public enum VersionParser {
    public static func parse(_ text: String) -> Version? {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let major = Int(parts[0]), let minor = Int(parts[1]), let patch = Int(parts[2]),
              major >= 0, minor >= 0, patch >= 0
        else { return nil }
        return Version(major: major, minor: minor, patch: patch)
    }
}
