import Foundation

public enum SlugMaker {
    public static func slug(from title: String) -> String {
        let lowered = title.lowercased()
        let allowed = lowered.map { character -> Character in
            character.isLetter || character.isNumber ? character : "-"
        }
        let collapsed = String(allowed).split(separator: "-", omittingEmptySubsequences: true)
        return collapsed.joined(separator: "-")
    }

    public static func isValid(_ slug: String) -> Bool {
        !slug.isEmpty && slug.allSatisfy { $0.isLowercase || $0.isNumber || $0 == "-" }
    }
}
