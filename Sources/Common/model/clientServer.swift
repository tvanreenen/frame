import Foundation

// TO EVERYONE REVERSE-ENGINEERING THE PROTOCOL
// client-server socket API is not public yet.
// Tracking issue for making it public: https://github.com/nikitabobko/AeroSpace/issues/1513
public struct ServerAnswer: Codable, Sendable {
    public let exitCode: Int32
    public let stdout: String
    public var stderr: String
    public let serverVersionAndHash: String

    public init(
        exitCode: Int32,
        stdout: String = "",
        stderr: String = "",
        serverVersionAndHash: String,
    ) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
        self.serverVersionAndHash = serverVersionAndHash
    }
}

// TO EVERYONE REVERSE-ENGINEERING THE PROTOCOL
// client-server socket API is not public yet.
// Tracking issue for making it public: https://github.com/nikitabobko/AeroSpace/issues/1513
public struct ClientRequest: Codable, Sendable, ConvenienceCopyable, Equatable {
    public let args: [String]
    public let stdin: String

    // Please forward AEROSPACE_WINDOW_ID and AEROSPACE_WORKSPACE to these fields.
    // The fields are required to be present in the JSON payload and can be null.
    public var windowId: UInt32?
    public var workspace: String?

    public init(
        args: [String],
        stdin: String,
        windowId: UInt32?,
        workspace: String?,
    ) {
        self.args = args
        self.stdin = stdin
        self.windowId = windowId
        self.workspace = workspace
    }

    public static func decodeJson(_ data: Data) -> Result<ClientRequest, String> {
        Result { try JSONDecoder().decode(Self.self, from: data) }.mapError { $0.localizedDescription }
    }

    enum CodingKeys: String, CodingKey {
        case args
        case stdin
        case windowId
        case workspace
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        args = try container.decode([String].self, forKey: .args)
        stdin = try container.decode(String.self, forKey: .stdin)
        guard container.contains(.windowId) else {
            throw DecodingError.keyNotFound(
                CodingKeys.windowId,
                DecodingError.Context(codingPath: container.codingPath, debugDescription: "'windowId' field is mandatory"),
            )
        }
        guard container.contains(.workspace) else {
            throw DecodingError.keyNotFound(
                CodingKeys.workspace,
                DecodingError.Context(codingPath: container.codingPath, debugDescription: "'workspace' field is mandatory"),
            )
        }
        windowId = try container.decode(UInt32?.self, forKey: .windowId)
        workspace = try container.decode(String?.self, forKey: .workspace)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(args, forKey: .args)
        try container.encode(stdin, forKey: .stdin)
        try container.encode(windowId, forKey: .windowId)
        try container.encode(workspace, forKey: .workspace)
    }
}
