import AppKit
import Common

final class Window: TreeNode, Hashable {
    let windowId: UInt32
    let app: any WindowPlatformApp
    var lastFloatingSize: CGSize?
    var isFullscreen: Bool = false
    var noOuterGapsInFullscreen: Bool = false
    var layoutReason: LayoutReason = .standard
    private var prevUnhiddenProportionalPositionInsideWorkspaceRect: CGPoint?

    @MainActor static var allWindowsMap: [UInt32: Window] {
        get { runtimeContext.windowsById }
        set { runtimeContext.windowsById = newValue }
    }
    @MainActor static var allWindows: [Window] { Array(runtimeContext.windowsById.values) }

    @MainActor
    init(
        id: UInt32,
        _ app: any WindowPlatformApp,
        lastFloatingSize: CGSize?,
        parent: NonLeafTreeNodeObject,
        adaptiveWeight: CGFloat,
        index: Int,
    ) {
        self.windowId = id
        self.app = app
        self.lastFloatingSize = lastFloatingSize
        super.init(parent: parent, adaptiveWeight: adaptiveWeight, index: index)
    }

    @MainActor static func get(byId windowId: UInt32) -> Window? { // todo make non optional
        allWindowsMap[windowId]
    }

    @MainActor
    @discardableResult
    static func getOrRegister(windowId: UInt32, app: any WindowPlatformApp) async throws -> Window {
        if let existing = allWindowsMap[windowId] { return existing }
        let rect = try await app.getAxRect(windowId: windowId)
        let data = try await unbindAndGetBindingDataForNewWindow(
            windowId,
            app,
            isStartup
                ? (rect?.center.monitorApproximation ?? mainMonitor).activeWorkspace
                : focus.workspace,
            window: nil,
        )

        // atomic synchronous section
        if let existing = allWindowsMap[windowId] { return existing }
        let window = Window(
            id: windowId,
            app,
            lastFloatingSize: rect?.size,
            parent: data.parent,
            adaptiveWeight: data.adaptiveWeight,
            index: data.index,
        )
        allWindowsMap[windowId] = window

        _ = try await restoreClosedWindowsCacheIfNeeded(newlyDetectedWindow: window)
        return window
    }

    @MainActor
    static func registerForTests(_ window: Window) {
        allWindowsMap[window.windowId] = window
    }

    @MainActor
    static func resetForTests() {
        allWindowsMap = [:]
    }

    @MainActor
    func closeAxWindow() {
        garbageCollect(skipClosedWindowsCache: true)
        app.closeAndUnregisterAxWindow(windowId: windowId)
    }

    nonisolated public func hash(into hasher: inout Hasher) {
        hasher.combine(windowId)
    }

    func getAxTopLeftCorner() async throws -> CGPoint? { try await app.getAxTopLeftCorner(windowId: windowId) }
    func getAxSize() async throws -> CGSize? { try await app.getAxSize(windowId: windowId) }
    var title: String { get async throws { try await app.getAxTitle(windowId: windowId) ?? "" } }
    var isMacosFullscreen: Bool { get async throws { try await app.isMacosNativeFullscreen(windowId: windowId) == true } }
    var isMacosMinimized: Bool { get async throws { try await app.isMacosNativeMinimized(windowId: windowId) == true } } // todo replace with enum MacOsWindowNativeState { normal, fullscreen, invisible }
    var isHiddenInCorner: Bool { prevUnhiddenProportionalPositionInsideWorkspaceRect != nil }
    @MainActor
    func nativeFocus() { app.nativeFocus(windowId: windowId) }
    func getAxRect() async throws -> Rect? { try await app.getAxRect(windowId: windowId) }
    func getCenter() async throws -> CGPoint? { try await getAxRect()?.center }

    func setAxFrameBlocking(_ topLeft: CGPoint?, _ size: CGSize?) async throws {
        try await app.setAxFrameBlocking(windowId: windowId, topLeft: topLeft, size: size)
    }

    func setAxFrame(_ topLeft: CGPoint?, _ size: CGSize?) {
        app.setAxFrame(windowId: windowId, topLeft: topLeft, size: size)
    }

    @MainActor
    func getResolvedAxUiElementWindowType(_ windowLevel: MacOsWindowLevel?) async throws -> AxUiElementWindowType {
        try await Window.resolveWindowType(windowId: windowId, app: app, windowLevel: windowLevel)
    }

    func dumpAxInfo() async throws -> [String: Json] {
        try await app.dumpWindowAxInfo(windowId: windowId)
    }

    @MainActor
    func hideInCorner(_ corner: OptimalHideCorner) async throws {
        guard let nodeMonitor else { return }
        // Don't accidentally override prevUnhiddenProportionalPositionInsideWorkspaceRect in case of subsequent
        // hideInCorner calls
        if !isHiddenInCorner {
            guard let windowRect = try await getAxRect() else { return }
            let topLeftCorner = windowRect.topLeftCorner
            let monitorRect = windowRect.center.monitorApproximation.rect // Similar to layoutFloatingWindow. Non idempotent
            let absolutePoint = topLeftCorner - monitorRect.topLeftCorner
            prevUnhiddenProportionalPositionInsideWorkspaceRect =
                CGPoint(x: absolutePoint.x / monitorRect.width, y: absolutePoint.y / monitorRect.height)
        }
        let p: CGPoint
        switch corner {
            case .bottomLeftCorner:
                guard let s = try await getAxSize() else { fallthrough }
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
        setAxFrame(p, nil)
    }

    @MainActor
    func unhideFromCorner() {
        guard let prevUnhiddenProportionalPositionInsideWorkspaceRect else { return }
        guard let nodeWorkspace else { return } // hiding only makes sense for workspace windows
        guard let parent else { return }

        switch getChildParentRelation(child: self, parent: parent) {
            // Just a small optimization to avoid unnecessary AX calls for non floating windows
            // Tiling windows should be unhidden with layoutRecursive anyway
            case .floatingWindow:
                let workspaceRect = nodeWorkspace.workspaceMonitor.rect
                let pointInsideWorkspace = CGPoint(
                    x: workspaceRect.width * prevUnhiddenProportionalPositionInsideWorkspaceRect.x,
                    y: workspaceRect.height * prevUnhiddenProportionalPositionInsideWorkspaceRect.y,
                )
                setAxFrame(workspaceRect.topLeftCorner + pointInsideWorkspace, nil)
            case .macosNativeFullscreenWindow, .macosNativeHiddenAppWindow, .macosNativeMinimizedWindow,
                 .macosPopupWindow, .tiling, .rootTilingContainer, .shimContainerRelation:
                break
        }

        self.prevUnhiddenProportionalPositionInsideWorkspaceRect = nil
    }

    // skipClosedWindowsCache is an optimization when it's definitely not necessary to cache closed window.
    //                        If you are unsure, it's better to pass `false`
    @MainActor
    func garbageCollect(skipClosedWindowsCache: Bool) {
        if Window.allWindowsMap.removeValue(forKey: windowId) == nil {
            return
        }
        if !skipClosedWindowsCache { cacheClosedWindowIfNeeded() }
        let parent = unbindFromParent().parent
        let deadWindowWorkspace = parent.nodeWorkspace
        let focus = focus
        if let deadWindowWorkspace, deadWindowWorkspace == focus.workspace ||
            deadWindowWorkspace == prevFocusedWorkspace && prevFocusedWorkspaceDate.distance(to: .now) < 1
        {
            if parent is Column || parent is Workspace || parent is MacosHiddenAppsWindowsContainer || parent is MacosFullscreenWindowsContainer {
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
    static func resolveWindowType(
        windowId: UInt32,
        app: any WindowPlatformApp,
        windowLevel: MacOsWindowLevel?,
    ) async throws -> AxUiElementWindowType {
        let heuristicType = try await app.getAxUiElementWindowType(windowId: windowId, windowLevel: windowLevel)
        let overrides = runtimeContext.config.windowClassificationOverrides
        guard !overrides.isEmpty else { return heuristicType }

        let appBundleId = app.rawAppBundleId
        let appName = app.name
        var cachedTitle: String? = nil

        for override in overrides {
            if override.matcher.windowTitleRegexSubstring != nil, cachedTitle == nil {
                cachedTitle = try await app.getAxTitle(windowId: windowId) ?? ""
            }
            if override.matcher.matches(appBundleId: appBundleId, appName: appName, windowTitle: cachedTitle) {
                return override.resolvedKind
            }
        }
        return heuristicType
    }
}

enum LayoutReason: Equatable {
    case standard
    /// Reason for the cur temp layout is macOS native fullscreen, minimize, or hide
    case macos(previousPlacement: PreviousMacOsWindowPlacement)
}

enum PreviousMacOsWindowPlacement: Equatable {
    case floating
    case tiled
    case reclassify
}

extension Window {
    var isFloating: Bool { parent is Workspace } // todo drop. It will be a source of bugs when sticky is introduced

    @discardableResult
    @MainActor
    func bindAsFloatingWindow(to workspace: Workspace) -> BindingData? {
        bind(to: workspace, adaptiveWeight: WEIGHT_AUTO, index: INDEX_BIND_LAST)
    }
}
