import AppKit
import ApplicationServices
import FrameEngine

func refreshObs(_ obs: AXObserver, ax: AXUIElement, notif: CFString, data: UnsafeMutableRawPointer?) {
    let notif = notif as String
    let session = AppSession.fromCallbackContext(data)
    var pid = pid_t()
    let hasPid = AXUIElementGetPid(ax, &pid) == .success
    let bundleId = hasPid ? NSRunningApplication(processIdentifier: pid)?.bundleIdentifier : nil
    Task { @MainActor in
        let session = session ?? currentSession
        session.windowEventsDiagnosticsLogger.logAxNotification(
            notification: notif,
            bundleId: bundleId,
            pid: hasPid ? pid : nil,
        )
        session.scheduleRefreshSession(.ax(notif))
    }
}
