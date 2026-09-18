//
//  SubjectAdvisory.swift
//  SwiftTestLab
//
//  Created by Manju on 18/09/2026.
//

import Foundation

/// Things worth saying before a run rather than after a confusing build failure.
///
/// These are warnings, never blocks — the user may know something we don't.
public enum SubjectAdvisory {
    public static func warnings(for subject: TestSubject, source: String) -> [String] {
        var warnings: [String] = []

        if case .inPackage(let package, let file) = subject {
            let reachable = package.testTarget.dependencyNames
            if !reachable.isEmpty && !reachable.contains(file.moduleName) {
                warnings.append(
                    "The \(package.testTarget.name) target doesn't depend on \(file.moduleName), "
                    + "so it can't import it. This test won't compile until "
                    + "\(file.moduleName) is added to that target's dependencies in Package.swift."
                )
            }
        }

        if case .standalone = subject {
            if source.contains(/^\s*import\s+(UIKit|WatchKit)\b/.anchorsMatchLineEndings()) {
                warnings.append(
                    "This file imports UIKit, but the throwaway package is built for macOS. "
                    + "It won't compile here — open its package instead, if it has one."
                )
            } else if containsUIKitOnlyAPI(source) {
                warnings.append(
                    "SwiftUI itself is fine, but this file uses iOS-only API. Verification "
                    + "runs swift test on macOS, and running iOS code needs a simulator — "
                    + "which this app deliberately doesn't do."
                )
            }
        }

        if isLikelyAView(source) {
            warnings.append(
                "A SwiftUI view's body isn't something a unit test can call. Expect a thin "
                + "test — the logic behind the view is usually the better subject."
            )
        }

        return warnings
    }

    private static func containsUIKitOnlyAPI(_ source: String) -> Bool {
        let markers = [
            "navigationBarTrailing", "navigationBarLeading", "navigationBarTitleDisplayMode",
            "UIApplication", "UIViewController", "UIScreen", "UIImage(",
        ]
        return markers.contains { source.contains($0) }
    }

    private static func isLikelyAView(_ source: String) -> Bool {
        source.contains(/:\s*View\s*\{/) && source.contains("var body")
    }
}
