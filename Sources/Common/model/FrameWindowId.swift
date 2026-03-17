import Foundation

public struct FrameWindowId: Hashable, Sendable, Codable, CustomStringConvertible, ExpressibleByIntegerLiteral {
    public static let prefix = "frame-"

    public let serial: UInt32

    public init(serial: UInt32) {
        self.serial = serial
    }

    public init(integerLiteral value: Int) {
        self.init(serial: UInt32(value))
    }

    public init?(_ raw: String) {
        guard raw.hasPrefix(Self.prefix) else { return nil }
        guard let serial = UInt32(raw.dropFirst(Self.prefix.count)) else { return nil }
        self.init(serial: serial)
    }

    public var description: String { "\(Self.prefix)\(serial)" }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        guard let id = FrameWindowId(raw) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid FrameWindowId '\(raw)'")
        }
        self = id
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
