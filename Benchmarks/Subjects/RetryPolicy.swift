import Foundation

public protocol Clock2 {
    func now() -> Int
}

public struct RetryPolicy {
    private let clock: Clock2
    private let limit: Int

    public init(clock: Clock2, limit: Int) {
        self.clock = clock
        self.limit = limit
    }

    public func delay(forAttempt attempt: Int) -> Int {
        guard attempt > 0 else { return 0 }
        return min(1 << (attempt - 1), 60)
    }

    public func shouldRetry(attempt: Int, startedAt: Int, budget: Int) -> Bool {
        attempt < limit && (clock.now() - startedAt) < budget
    }
}
