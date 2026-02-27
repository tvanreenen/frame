public let stableSimpleWmAppId: String = "com.simplewm.app"
#if DEBUG
    public let simpleWmAppId: String = "com.simplewm.app.debug"
    public let simpleWmAppName: String = "simple-wm-Debug"
#else
    public let simpleWmAppId: String = stableSimpleWmAppId
    public let simpleWmAppName: String = "simple-wm"
#endif
