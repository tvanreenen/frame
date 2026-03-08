import ApplicationServices
import FrameEngine

func refreshObs(_ obs: AXObserver, ax: AXUIElement, notif: CFString, data: UnsafeMutableRawPointer?) {
    let notif = notif as String
    let session = AppSession.fromCallbackContext(data)
    Task { @MainActor in
        (session ?? currentSession).scheduleRefreshSession(.ax(notif))
    }
}
