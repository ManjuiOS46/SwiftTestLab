import Foundation

public struct Money: Equatable {
    public let minorUnits: Int
    public let currency: String

    public init(minorUnits: Int, currency: String) {
        self.minorUnits = minorUnits
        self.currency = currency
    }

    public static func + (lhs: Money, rhs: Money) throws -> Money {
        guard lhs.currency == rhs.currency else { throw MoneyError.mismatchedCurrency }
        return Money(minorUnits: lhs.minorUnits + rhs.minorUnits, currency: lhs.currency)
    }

    public var formatted: String {
        String(format: "%@%.2f", currency == "USD" ? "$" : "", Double(minorUnits) / 100)
    }
}

public enum MoneyError: Error { case mismatchedCurrency }
