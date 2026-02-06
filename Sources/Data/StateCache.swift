import Foundation

struct CachedFocusState {
    let appName: String
    let bundleId: String
    let isFullscreen: Bool
    let timestamp: Date
}

final class StateCache {
    private let maxCount: Int
    private let retentionSeconds: TimeInterval
    private var items: [CachedFocusState] = []

    init(maxCount: Int, retentionSeconds: TimeInterval = 24 * 60 * 60) {
        self.maxCount = max(1, maxCount)
        self.retentionSeconds = max(1, retentionSeconds)
    }

    func append(snapshot: FocusSnapshot) {
        let cached = CachedFocusState(
            appName: snapshot.appName,
            bundleId: snapshot.bundleId,
            isFullscreen: snapshot.isFullscreen,
            timestamp: snapshot.timestamp
        )
        items.append(cached)
        trimIfNeeded()
    }

    var count: Int {
        items.count
    }

    private func trimIfNeeded() {
        trimByAge()
        if items.count > maxCount {
            items.removeFirst(items.count - maxCount)
        }
    }

    private func trimByAge() {
        let cutoff = Date().addingTimeInterval(-retentionSeconds)
        while let first = items.first, first.timestamp < cutoff {
            items.removeFirst()
        }
    }
}
