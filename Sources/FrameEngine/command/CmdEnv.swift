import Common

package struct CmdEnv: ConvenienceCopyable {
    package var windowId: FrameWindowId?
    package var workspaceName: String?

    package init(windowId: FrameWindowId? = nil, workspaceName: String? = nil) {
        self.windowId = windowId
        self.workspaceName = workspaceName
    }

    package static let defaultEnv: CmdEnv = .init()
    package func withFocus(_ focus: LiveFocus) -> CmdEnv {
        switch focus.asLeaf {
            case .window(let wd): .defaultEnv.copy(\.windowId, wd.windowId)
            case .emptyWorkspace(let ws): .defaultEnv.copy(\.workspaceName, ws.name)
        }
    }

    package var asMap: [String: String] {
        var result = [String: String]()
        if let windowId {
            result[FRAME_WINDOW_ID] = windowId.description
        }
        if let workspaceName {
            result[FRAME_WORKSPACE] = workspaceName.description
        }
        return result
    }
}
