import Common
import Foundation

package final class Window: TreeNode, Hashable {
    package let windowId: FrameWindowId
    package private(set) var platformWindowId: UInt32
    package let app: any WindowPlatformApp
    package var lastKnownSize: CGSize?
    package var isFullscreenOverlay: Bool = false
    package var noOuterGapsInFullscreenOverlay: Bool = false
    package var layoutReason: LayoutReason = .standard
    private var prevUnhiddenProportionalPositionInsideWorkspaceRect: CGPoint?

    @MainActor package static var allWindowsMap: [FrameWindowId: Window] {
        get { runtimeContext.windowsById }
        set { runtimeContext.windowsById = newValue }
    }
    @MainActor private static var frameIdByPlatformWindowId: [UInt32: FrameWindowId] {
        get { runtimeContext.frameIdByPlatformWindowId }
        set { runtimeContext.frameIdByPlatformWindowId = newValue }
    }
    @MainActor package static var allWindows: [Window] { Array(runtimeContext.windowsById.values) }

    @MainActor
    package init(
        id: FrameWindowId,
        platformWindowId: UInt32,
        _ app: any WindowPlatformApp,
        lastKnownSize: CGSize?,
        parent: NonLeafTreeNodeObject,
        adaptiveWeight: CGFloat,
        index: Int,
    ) {
        self.windowId = id
        self.platformWindowId = platformWindowId
        self.app = app
        self.lastKnownSize = lastKnownSize
        super.init(parent: parent, adaptiveWeight: adaptiveWeight, index: index)
    }

    @MainActor package static func get(byId windowId: FrameWindowId) -> Window? { // todo make non optional
        allWindowsMap[windowId]
    }

    @MainActor
    @discardableResult
    package static func get(byPlatformWindowId platformWindowId: UInt32) -> Window? {
        frameIdByPlatformWindowId[platformWindowId].flatMap { allWindowsMap[$0] }
    }

    @MainActor
    @discardableResult
    package static func getOrRegister(windowId: UInt32, app: any WindowPlatformApp) async throws -> Window {
        if let existing = get(byPlatformWindowId: windowId) { return existing }
        let rect = try await app.getWindowRect(windowId: windowId)
        let data = try await unbindAndGetBindingDataForNewWindow(
            windowId,
            app,
            isStartup
                ? (rect?.center.monitorApproximation ?? mainMonitor).activeWorkspace
                : focus.workspace,
            window: nil,
        )

        // atomic synchronous section
        if let existing = get(byPlatformWindowId: windowId) { return existing }
        let window = Window(
            id: currentSession.makeFrameWindowId(),
            platformWindowId: windowId,
            app,
            lastKnownSize: rect?.size,
            parent: data.parent,
            adaptiveWeight: data.adaptiveWeight,
            index: data.index,
        )
        allWindowsMap[window.windowId] = window
        frameIdByPlatformWindowId[windowId] = window.windowId
        let session = currentSession
        if session.windowEventsDiagnosticsLogger.isEnabled(forBundleId: app.rawAppBundleId) {
            let placementKind = try await Window.resolvePlacementKind(windowId: windowId, app: app)
            let title = try await app.getWindowTitle(windowId: windowId)
            session.windowEventsDiagnosticsLogger.logWindowRegistered(
                bundleId: app.rawAppBundleId,
                pid: app.pid,
                windowId: windowId,
                placementKind: placementKind,
                title: title,
            )
        }
        return window
    }

    @MainActor
    package static func registerForTests(_ window: Window) {
        allWindowsMap[window.windowId] = window
        frameIdByPlatformWindowId[window.platformWindowId] = window.windowId
    }

    @MainActor
    package static func resetForTests() {
        allWindowsMap = [:]
        frameIdByPlatformWindowId = [:]
    }

    @MainActor
    func closeWindow() {
        garbageCollect()
        app.closeAndUnregisterWindow(windowId: platformWindowId)
    }

    @MainActor
    package func rebind(toPlatformWindowId newPlatformWindowId: UInt32, lastKnownSize: CGSize?) {
        let oldPlatformWindowId = platformWindowId
        Window.frameIdByPlatformWindowId.removeValue(forKey: platformWindowId)
        platformWindowId = newPlatformWindowId
        Window.frameIdByPlatformWindowId[newPlatformWindowId] = windowId
        if let lastKnownSize {
            self.lastKnownSize = lastKnownSize
        }
        currentSession.windowEventsDiagnosticsLogger.logWindowRebound(
            bundleId: app.rawAppBundleId,
            pid: app.pid,
            frameWindowId: windowId,
            oldPlatformWindowId: oldPlatformWindowId,
            newPlatformWindowId: newPlatformWindowId,
        )
    }

    nonisolated public func hash(into hasher: inout Hasher) {
        hasher.combine(windowId)
    }

    package func getTopLeftCorner() async throws -> CGPoint? { try await app.getWindowTopLeftCorner(windowId: platformWindowId) }
    package func getSize() async throws -> CGSize? { try await app.getWindowSize(windowId: platformWindowId) }
    package var title: String { get async throws { try await app.getWindowTitle(windowId: platformWindowId) ?? "" } }
    package var isNativeFullscreen: Bool { get async throws { try await app.isNativeFullscreen(windowId: platformWindowId) == true } }
    package var isNativeMinimized: Bool { get async throws { try await app.isNativeMinimized(windowId: platformWindowId) == true } } // todo replace with enum NativeWindowState { normal, fullscreen, invisible }
    package var isHiddenInCorner: Bool { prevUnhiddenProportionalPositionInsideWorkspaceRect != nil }
    @MainActor
    package func nativeFocus() { currentSession.platformServices.nativeFocusWindow(app, platformWindowId) }
    package func getRect() async throws -> Rect? { try await app.getWindowRect(windowId: platformWindowId) }
    package func getCenter() async throws -> CGPoint? { try await getRect()?.center }

    package func setFrameBlocking(_ topLeft: CGPoint?, _ size: CGSize?) async throws {
        try await app.setWindowFrameBlocking(windowId: platformWindowId, topLeft: topLeft, size: size)
    }

    package func setFrame(_ topLeft: CGPoint?, _ size: CGSize?) {
        app.setWindowFrame(windowId: platformWindowId, topLeft: topLeft, size: size)
    }

    @MainActor
    package func getResolvedPlacementKind() async throws -> WindowPlacementKind {
        try await Window.resolvePlacementKind(windowId: platformWindowId, app: app)
    }

    package func dumpWindowInfo() async throws -> [String: Json] {
        try await app.dumpWindowInfo(windowId: platformWindowId)
    }

    @MainActor
    package func hideInCorner(_ corner: OptimalHideCorner) async throws {
        guard let nodeMonitor else { return }
        // Don't accidentally override prevUnhiddenProportionalPositionInsideWorkspaceRect in case of subsequent
        // hideInCorner calls
        if !isHiddenInCorner {
            guard let windowRect = try await getRect() else { return }
            let topLeftCorner = windowRect.topLeftCorner
            let monitorRect = windowRect.center.monitorApproximation.rect // Similar to layoutFloatingWindow. Non idempotent
            let absolutePoint = topLeftCorner - monitorRect.topLeftCorner
            prevUnhiddenProportionalPositionInsideWorkspaceRect =
                CGPoint(x: absolutePoint.x / monitorRect.width, y: absolutePoint.y / monitorRect.height)
        }
        let p: CGPoint
        switch corner {
            case .bottomLeftCorner:
                guard let s = try await getSize() else { fallthrough }
                // Zoom will jump off if you do one pixel offset https://github.com/tvanreenen/frame/issues/527
                // todo this ad hoc won't be necessary once I implement optimization suggested by Zalim
                let onePixelOffset = app.rawAppBundleId == KnownBundleId.zoom.rawValue ? .zero : CGPoint(x: 1, y: -1)
                p = nodeMonitor.visibleRect.bottomLeftCorner + onePixelOffset + CGPoint(x: -s.width, y: 0)
            case .bottomRightCorner:
                // Zoom will jump off if you do one pixel offset https://github.com/tvanreenen/frame/issues/527
                // todo this ad hoc won't be necessary once I implement optimization suggested by Zalim
                let onePixelOffset = app.rawAppBundleId == KnownBundleId.zoom.rawValue ? .zero : CGPoint(x: 1, y: 1)
                p = nodeMonitor.visibleRect.bottomRightCorner - onePixelOffset
        }
        setFrame(p, nil)
    }

    @MainActor
    package func unhideFromCorner() {
        guard let prevUnhiddenProportionalPositionInsideWorkspaceRect else { return }
        guard let nodeWorkspace else { return } // hiding only makes sense for workspace windows
        guard let parent else { return }

        switch getChildParentRelation(child: self, parent: parent) {
            // Just a small optimization to avoid unnecessary AX calls for excluded windows.
            // Tiling windows should be unhidden with layoutRecursive anyway
            case .excludedWindow:
                let workspaceRect = nodeWorkspace.workspaceMonitor.rect
                let pointInsideWorkspace = CGPoint(
                    x: workspaceRect.width * prevUnhiddenProportionalPositionInsideWorkspaceRect.x,
                    y: workspaceRect.height * prevUnhiddenProportionalPositionInsideWorkspaceRect.y,
                )
                setFrame(workspaceRect.topLeftCorner + pointInsideWorkspace, nil)
            case .nativeFullscreenWindow, .hiddenAppWindow, .nativeMinimizedWindow,
                 .tiling, .rootTilingContainer, .shimContainerRelation:
                break
        }

        self.prevUnhiddenProportionalPositionInsideWorkspaceRect = nil
    }

    @MainActor
    package func garbageCollect() {
        if Window.allWindowsMap.removeValue(forKey: windowId) == nil {
            return
        }
        Window.frameIdByPlatformWindowId.removeValue(forKey: platformWindowId)
        currentSession.windowEventsDiagnosticsLogger.logWindowGarbageCollected(
            bundleId: app.rawAppBundleId,
            pid: app.pid,
            windowId: platformWindowId,
        )
        let parent = unbindFromParent().parent
        let deadWindowWorkspace = parent.nodeWorkspace
        let focus = focus
        if let deadWindowWorkspace, deadWindowWorkspace == focus.workspace ||
            deadWindowWorkspace == prevFocusedWorkspace && prevFocusedWorkspaceDate.distance(to: .now) < 1
        {
            if parent is Column || parent is Workspace || parent is HiddenAppWindowsContainer || parent is NativeFullscreenWindowsContainer {
                let deadWindowFocus = deadWindowWorkspace.toLiveFocus()
                _ = setFocus(to: deadWindowFocus)
                // Guard against "Apple Reminders popup" bug: https://github.com/tvanreenen/frame/issues/201
                if focus.windowOrNil?.app.pid != app.pid {
                    // Force focus to fix macOS annoyance with focused apps without windows.
                    //   https://github.com/tvanreenen/frame/issues/65
                    deadWindowFocus.windowOrNil?.nativeFocus()
                }
            }
        }
    }
}

extension Window {
    @MainActor
    static func resolvePlacementKind(
        windowId: UInt32,
        app: any WindowPlatformApp,
    ) async throws -> WindowPlacementKind {
        let heuristicType = try await app.getWindowPlacementKind(windowId: windowId)
        let overrides = runtimeContext.config.windowClassificationOverrides
        guard !overrides.isEmpty else { return heuristicType }

        let appBundleId = app.rawAppBundleId
        let appName = app.name
        var cachedTitle: String? = nil

        for override in overrides {
            if override.matcher.windowTitleRegexSubstring != nil, cachedTitle == nil {
                cachedTitle = try await app.getWindowTitle(windowId: windowId) ?? ""
            }
            if override.matcher.matches(appBundleId: appBundleId, appName: appName, windowTitle: cachedTitle) {
                return override.resolvedKind
            }
        }
        return heuristicType
    }
}

package enum LayoutReason: Equatable {
    case standard
    /// Reason for the cur temp layout is macOS native fullscreen, minimize, or hide
    case platformDisplaced(previousPlacement: PreviousWindowPlacement)
}

package enum PreviousWindowPlacement: Equatable {
    case tiled
    case reclassify
}
