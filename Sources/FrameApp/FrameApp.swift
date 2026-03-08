import FrameMacOS
import FrameUI
import SwiftUI

// This file is shared between SPM and xcode project

@main
struct FrameApp: App {
    @StateObject var viewModel = TrayMenuModel.shared
    @StateObject var messageModel = MessageModel.shared
    @Environment(\.openWindow) var openWindow: OpenWindowAction

    init() {
        initFrameAppRuntime()
    }

    var body: some Scene {
        menuBar(viewModel: viewModel, metadata: menuBarMetadata(), onQuit: quitFromMenuBar)
        getMessageWindow(messageModel: messageModel)
            .onChange(of: messageModel.message) { message in
                if message != nil {
                    openWindow(id: messageWindowId)
                }
            }
    }
}
