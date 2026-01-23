struct RuleConfig {
    let fullscreenNonWork: Bool
    let whitelistBundleIds: Set<String>
    let autoStartBundleIds: Set<String>
}

struct RuleEngine {
    let config: RuleConfig

    func isWork(snapshot: FocusSnapshot) -> Bool {
        if !config.autoStartBundleIds.isEmpty && !config.autoStartBundleIds.contains(snapshot.bundleId) {
            return false
        }
        if snapshot.isFullscreen {
            if snapshot.bundleId == "com.apple.Safari" {
                return false
            }
            if config.fullscreenNonWork && !config.whitelistBundleIds.contains(snapshot.bundleId) {
                return false
            }
        }
        return true
    }

    func isWork(snapshot: FocusSnapshot, runningAllowlistApps: Set<String>) -> Bool {
        if !config.autoStartBundleIds.isEmpty {
            return !config.autoStartBundleIds.intersection(runningAllowlistApps).isEmpty
        }
        return isWork(snapshot: snapshot)
    }
}
