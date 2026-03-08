import AppKit
import Common
import FrameEngine
import FrameUI

extension AppSession {
    @MainActor
    package func syncUiState() {
        SecureInputPanel.shared.configure(
            SecureInputPanelDependencies(
                hasBindings: { !self.config.bindings.isEmpty },
                mainMonitorWidth: { mainMonitor.width },
            )
        )
        syncTrayText()
        SecureInputPanel.shared.refresh()
    }

    @MainActor
    func syncTrayText() {
        let sortedMonitors = sortedMonitors
        let currentFocus = self.focus
        TrayMenuModel.shared.trayText = sortedMonitors
            .map {
                ($0.activeWorkspace == currentFocus.workspace && sortedMonitors.count > 1 ? "*" : "") + $0.activeWorkspace.name
            }
            .joined(separator: " │ ")
    }

    @MainActor
    func clearConfigMessage() {
        MessageModel.shared.message = nil
    }

    @MainActor
    func setConfigMessage(_ message: Message) {
        MessageModel.shared.message = message
    }
}
