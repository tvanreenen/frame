public let productName: String = "Frame"
public let cliName: String = "frame"
public let stableAppBundleId: String = "com.frame.app"
public let configDotfileName: String = ".frame.toml"
public let configDirName: String = "frame"

#if DEBUG
    public let appBundleId: String = "com.frame.app.debug"
    public let appDisplayName: String = "Frame-Debug"
#else
    public let appBundleId: String = stableAppBundleId
    public let appDisplayName: String = productName
#endif
