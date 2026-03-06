import AppKit
import Common

extension AppSession {
    @MainActor
    func syncUiState() {
        syncTrayText()
        SecureInputPanel.shared.refresh()
    }

    @MainActor
    func syncTrayText() {
        let sortedMonitors = sortedMonitors
        let focus = focus
        TrayMenuModel.shared.trayText = sortedMonitors
            .map {
                ($0.activeWorkspace == focus.workspace && sortedMonitors.count > 1 ? "*" : "") + $0.activeWorkspace.name
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
