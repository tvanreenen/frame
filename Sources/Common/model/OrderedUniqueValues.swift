public struct OrderedUniqueValues<Element: Hashable & Sendable>: ExpressibleByArrayLiteral, RandomAccessCollection, Equatable, Sendable {
    private var ordered: [Element]
    private var membership: Set<Element>

    public init() {
        ordered = []
        membership = []
    }

    public init(arrayLiteral elements: Element...) {
        self.init(deduplicating: elements)
    }

    public init(deduplicating elements: [Element]) {
        var ordered: [Element] = []
        var membership: Set<Element> = []
        ordered.reserveCapacity(elements.count)
        for element in elements where membership.insert(element).inserted {
            ordered.append(element)
        }
        self.ordered = ordered
        self.membership = membership
    }

    public init?(validatingUnique elements: [Element]) {
        var membership: Set<Element> = []
        for element in elements where !membership.insert(element).inserted {
            return nil
        }
        ordered = elements
        self.membership = membership
    }

    public var startIndex: Int { ordered.startIndex }
    public var endIndex: Int { ordered.endIndex }
    public subscript(position: Int) -> Element { ordered[position] }
    public var count: Int { ordered.count }

    public func contains(_ element: Element) -> Bool {
        membership.contains(element)
    }
}
