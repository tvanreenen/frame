public enum VersionPresentation {
    public static let daemonNotRunning = "Not Running"
    private static let configValidPrefix = "Config is valid: "
    private static let failedToParsePrefix = "Failed to parse "

    public static func doctorOutput(
        cliVersion: String,
        daemonVersion: String?,
        configHealthy: Bool?,
        configDetails: String?,
    ) -> String {
        let versionsMatch = versionsMatchString(cliVersion: cliVersion, daemonVersion: daemonVersion)
        let configSummary = summarizeConfig(daemonVersion: daemonVersion, configHealthy: configHealthy, configDetails: configDetails)

        var lines = [
            "CLI Version: \(cliVersion)",
            "Daemon Version: \(daemonVersion ?? daemonNotRunning)",
            "Versions Match: \(versionsMatch)",
            "Config Location: \(configSummary.location)",
            "Config Status: \(configSummary.status)",
        ]

        if let issues = configSummary.issues, !issues.trim().isEmpty {
            lines.append("Config Issues:")
            lines.append(issues.trim())
        }
        return lines.joined(separator: "\n")
    }

    public static func doctorExitCode(cliVersion: String, daemonVersion: String?, configHealthy: Bool?) -> Int32 {
        daemonVersion == cliVersion && configHealthy == true ? 0 : 1
    }

    private static func versionsMatchString(cliVersion: String, daemonVersion: String?) -> String {
        guard let daemonVersion else { return "Unknown (daemon not running)" }
        return daemonVersion == cliVersion ? "Yes" : "No"
    }

    private static func summarizeConfig(
        daemonVersion: String?,
        configHealthy: Bool?,
        configDetails: String?,
    ) -> (location: String, status: String, issues: String?) {
        guard daemonVersion != nil else {
            return ("Unknown", "Unknown (daemon not running)", nil)
        }

        let details = configDetails?.trim() ?? ""

        guard let configHealthy else {
            return ("Unknown", "Unknown", details.isEmpty ? nil : details)
        }

        if configHealthy {
            if let location = extractLocationFromValidMessage(details) {
                return (location, "Valid", nil)
            }
            return ("Unknown", "Valid", nil)
        }

        let (location, issues) = parseInvalidConfigDetails(details)
        return (location, "Invalid", issues)
    }

    private static func extractLocationFromValidMessage(_ details: String) -> String? {
        details
            .split(separator: "\n")
            .map(String.init)
            .first(where: { $0.hasPrefix(configValidPrefix) })
            .map { String($0.dropFirst(configValidPrefix.count)).trim() }
            .flatMap { $0.isEmpty ? nil : $0 }
    }

    private static func parseInvalidConfigDetails(_ details: String) -> (location: String, issues: String) {
        let trimmed = details.trim()
        if trimmed.isEmpty {
            return ("Unknown", "Unknown configuration error")
        }

        let lines = trimmed.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let firstLine = lines.first?.trim() ?? ""

        var location = "Unknown"
        var issuesText = trimmed
        if firstLine.hasPrefix(failedToParsePrefix) {
            let maybeLocation = String(firstLine.dropFirst(failedToParsePrefix.count)).trim()
            if !maybeLocation.isEmpty { location = maybeLocation }
            issuesText = lines.dropFirst().joined(separator: "\n").trim()
        }

        if let recoveryRange = issuesText.range(of: "\n\nRecovery:\n") {
            issuesText = String(issuesText[..<recoveryRange.lowerBound]).trim()
        }

        if issuesText.isEmpty { issuesText = "Unknown configuration error" }
        return (location, issuesText)
    }
}
