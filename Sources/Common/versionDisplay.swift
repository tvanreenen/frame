private let snapshotSuffix = "-SNAPSHOT"

private func normalizeVersionForDisplay(_ version: String) -> String {
    guard version.hasSuffix(snapshotSuffix) else { return version }
    return String(version.dropLast(snapshotSuffix.count)) + "-dev"
}

public let appVersionForDisplay: String = {
    let normalized = normalizeVersionForDisplay(appVersion)
    if gitShortHash.isEmpty || gitShortHash == "SNAPSHOT" {
        return normalized
    }
    return "\(normalized)+\(gitShortHash)"
}()
