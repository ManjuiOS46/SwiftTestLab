import Foundation

public struct BoundedStack<Element> {
    private var storage: [Element] = []
    public let capacity: Int

    public init(capacity: Int) {
        self.capacity = max(0, capacity)
    }

    public var count: Int { storage.count }
    public var isEmpty: Bool { storage.isEmpty }

    @discardableResult
    public mutating func push(_ element: Element) -> Bool {
        guard storage.count < capacity else { return false }
        storage.append(element)
        return true
    }

    public mutating func pop() -> Element? {
        storage.popLast()
    }
}
