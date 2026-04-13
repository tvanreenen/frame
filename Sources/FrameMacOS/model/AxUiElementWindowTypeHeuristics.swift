import AppKit
import FrameEngine

private struct EmptyAxUiElementMock: AxUiElementMock {
    func get<Attr>(_ attr: Attr) -> Attr.T? where Attr: ReadableAttr { nil }
    func containingWindowId() -> CGWindowID? { nil }
}

struct ResolvedAxWindow {
    let windowId: UInt32
    let ax: any AxUiElementMock
    let source: WindowPlacementDecisionSource
}

enum WindowPlacementDecisionResolver {
    static func resolveAxWindow(
        windowId: UInt32,
        cachedWindow: (any AxUiElementMock)?,
        axApp: any AxUiElementMock,
    ) -> ResolvedAxWindow? {
        if let cachedWindow {
            return ResolvedAxWindow(
                windowId: windowId,
                ax: cachedWindow,
                source: .cachedAxWindow,
            )
        }
        if let focusedWindow = axApp.get(Ax.focusedWindowAttr), focusedWindow.windowId == windowId {
            return ResolvedAxWindow(
                windowId: windowId,
                ax: focusedWindow.ax,
                source: .focusedWindowLookup,
            )
        }
        if let axWindow = (axApp.get(Ax.windowsAttr) ?? []).first(where: { $0.windowId == windowId })?.ax {
            return ResolvedAxWindow(
                windowId: windowId,
                ax: axWindow,
                source: .windowsListLookup,
            )
        }
        return nil
    }

    static func resolveRegistrationSnapshot(
        windowId: UInt32,
        cachedWindow: (any AxUiElementMock)?,
        axApp: any AxUiElementMock,
        appId: String?,
        knownBundleId: KnownBundleId?,
        activationPolicy: NSApplication.ActivationPolicy,
        windowLevel: MacOsWindowLevel?,
    ) -> WindowRegistrationSnapshot? {
        guard let resolvedWindow = resolveAxWindow(
            windowId: windowId,
            cachedWindow: cachedWindow,
            axApp: axApp,
        ) else {
            return nil
        }
        return resolvedWindow.ax.getWindowRegistrationSnapshot(
            axApp: axApp,
            appId: appId,
            knownBundleId: knownBundleId,
            activationPolicy: activationPolicy,
            windowLevel: windowLevel,
        ).withSource(resolvedWindow.source)
    }

    static func resolve(
        windowId: UInt32,
        cachedWindow: (any AxUiElementMock)?,
        axApp: any AxUiElementMock,
        appId: String?,
        knownBundleId: KnownBundleId?,
        activationPolicy: NSApplication.ActivationPolicy,
        windowLevel: MacOsWindowLevel?,
    ) -> WindowPlacementDecision {
        if let snapshot = resolveRegistrationSnapshot(
            windowId: windowId,
            cachedWindow: cachedWindow,
            axApp: axApp,
            appId: appId,
            knownBundleId: knownBundleId,
            activationPolicy: activationPolicy,
            windowLevel: windowLevel,
        ) {
            return snapshot.placementDecision
        }
        return WindowPlacementDecision(
            placementKind: .excluded,
            reason: WindowPlacementDecisionSource.disappearedBeforeClassification.rawValue,
            source: WindowPlacementDecisionSource.disappearedBeforeClassification.rawValue,
        )
    }
}

extension AxUiElementMock {
    func makeWindowFacts(
        axApp: AxUiElementMock,
        appId: String?,
        knownBundleId: KnownBundleId?,
        activationPolicy: NSApplication.ActivationPolicy,
        windowLevel: MacOsWindowLevel?,
    ) -> WindowFacts {
        let windowId = containingWindowId() ?? 0
        let closeButton = get(Ax.closeButtonAttr)
        let minimizeButton = get(Ax.minimizeButtonAttr)
        let zoomButton = get(Ax.zoomButtonAttr)
        let fullscreenButton = get(Ax.fullscreenButtonAttr)
        return WindowFacts(
            appId: appId,
            knownBundleId: knownBundleId,
            windowId: windowId,
            title: get(Ax.titleAttr),
            role: get(Ax.roleAttr),
            subrole: get(Ax.subroleAttr),
            identifier: get(Ax.identifierAttr),
            isFocused: get(Ax.isFocused),
            isMain: get(Ax.isMainAttr),
            isModal: get(Ax.modalAttr),
            isMinimized: get(Ax.minimizedAttr),
            isFullscreen: get(Ax.isFullscreenAttr),
            matchesMainWindow: axApp.get(Ax.mainWindowAttr)?.windowId == windowId,
            matchesFocusedWindow: axApp.get(Ax.focusedWindowAttr)?.windowId == windowId,
            windowLevel: windowLevel,
            activationPolicy: activationPolicy,
            hasCloseButton: closeButton != nil,
            hasMinimizeButton: minimizeButton != nil,
            hasZoomButton: zoomButton != nil,
            hasFullscreenButton: fullscreenButton != nil,
            isCloseButtonEnabled: closeButton?.get(Ax.enabledAttr),
            isMinimizeButtonEnabled: minimizeButton?.get(Ax.enabledAttr),
            isZoomButtonEnabled: zoomButton?.get(Ax.enabledAttr),
            isFullscreenButtonEnabled: fullscreenButton?.get(Ax.enabledAttr),
        )
    }

    func isDialogHeuristic(_ id: KnownBundleId?, _ windowLevel: MacOsWindowLevel?) -> Bool {
        let facts = makeWindowFacts(
            axApp: EmptyAxUiElementMock(),
            appId: id?.rawValue,
            knownBundleId: id,
            activationPolicy: .regular,
            windowLevel: windowLevel,
        )
        return WindowClassifier.isDialog(facts)
    }

    func getWindowType(
        axApp: AxUiElementMock,
        _ id: KnownBundleId?,
        _ activationPolicy: NSApplication.ActivationPolicy,
        _ windowLevel: MacOsWindowLevel?,
    ) -> AxUiElementWindowType {
        WindowClassifier.axWindowType(
            makeWindowFacts(
                axApp: axApp,
                appId: id?.rawValue,
                knownBundleId: id,
                activationPolicy: activationPolicy,
                windowLevel: windowLevel,
            )
        )
    }

    func getWindowPlacementDecision(
        axApp: AxUiElementMock,
        appId: String?,
        knownBundleId: KnownBundleId?,
        activationPolicy: NSApplication.ActivationPolicy,
        windowLevel: MacOsWindowLevel?,
    ) -> WindowPlacementDecision {
        WindowClassifier.classify(
            makeWindowFacts(
                axApp: axApp,
                appId: appId,
                knownBundleId: knownBundleId,
                activationPolicy: activationPolicy,
                windowLevel: windowLevel,
            )
        )
    }

    func getWindowRegistrationSnapshot(
        axApp: AxUiElementMock,
        appId: String?,
        knownBundleId: KnownBundleId?,
        activationPolicy: NSApplication.ActivationPolicy,
        windowLevel: MacOsWindowLevel?,
    ) -> WindowRegistrationSnapshot {
        let topLeftCorner: CGPoint? = get(Ax.topLeftCornerAttr)
        let size: CGSize? = get(Ax.sizeAttr)
        let rect: Rect? = if let topLeftCorner, let size {
            Rect(topLeftX: topLeftCorner.x, topLeftY: topLeftCorner.y, width: size.width, height: size.height)
        } else {
            nil
        }
        return WindowRegistrationSnapshot(
            rect: rect,
            placementDecision: getWindowPlacementDecision(
                axApp: axApp,
                appId: appId,
                knownBundleId: knownBundleId,
                activationPolicy: activationPolicy,
                windowLevel: windowLevel,
            ),
        )
    }
}

extension WindowRegistrationSnapshot {
    fileprivate func withSource(_ source: WindowPlacementDecisionSource) -> WindowRegistrationSnapshot {
        var copy = self
        copy.placementDecision = copy.placementDecision.withSource(source)
        return copy
    }
}
