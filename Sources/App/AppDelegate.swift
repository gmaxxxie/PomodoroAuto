import AppKit
import Foundation
import UserNotifications
import QuartzCore

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private enum SessionState {
        case idle
        case running
        case paused
        case completed
        case resting
    }

    private let settings = SettingsStore()
    private let detector = FocusStateDetector()
    private var ruleEngine: RuleEngine
    private let statsStore = StatsStore()
    private let cache = StateCache(maxCount: 1000)
    private let workTimer: PomodoroTimer
    private let breakTimer: PomodoroTimer
    private let menuBar: MenuBarController

    override init() {
        self.ruleEngine = RuleEngine(config: settings.ruleConfig)
        self.workTimer = PomodoroTimer(durationSeconds: settings.workMinutes * 60)
        self.breakTimer = PomodoroTimer(durationSeconds: settings.breakMinutes * 60)
        self.menuBar = MenuBarController()
        super.init()
        menuBar.statsProvider = { [weak self] in
            guard let self else { return MenuBarController.TodayStats(pomodoroCount: 0, workSeconds: 0) }
            let stats = self.statsStore.statsForToday()
            return MenuBarController.TodayStats(pomodoroCount: stats.pomodoroCount, workSeconds: stats.workSeconds)
        }
        wireTimerCallbacks()
        wireMenuCallbacks()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureNotifications()
        _ = detector.requestAccess()
        startFocusDetection()
        updateStatusTextForCurrentState()
    }

    private func wireTimerCallbacks() {
        workTimer.onTick = { [weak self] remaining in
            guard let self else { return }
            self.menuBar.setRemaining(seconds: remaining, isBreak: false)
        }

        workTimer.onComplete = { [weak self] in
            guard let self else { return }
            self.endActiveSessionAndFlush()
            self.statsStore.incrementPomodoro()
            self.sendCompletionNotification()
            self.startBreak()
        }

        breakTimer.onTick = { [weak self] remaining in
            guard let self else { return }
            self.menuBar.setRemaining(seconds: remaining, label: "Break", isBreak: true)
        }

        breakTimer.onComplete = { [weak self] in
            guard let self else { return }
            self.state = .paused
            self.updateStatusTextForCurrentState()
            self.sendBreakEndedNotification()
        }
    }

    private func wireMenuCallbacks() {
        menuBar.onToggle = { [weak self] in
            self?.toggleRunning()
        }
        menuBar.onReset = { [weak self] in
            self?.resetTimer()
        }
        menuBar.onOpenStats = { [weak self] in
            self?.openStats()
        }
        menuBar.onOpenSettings = { [weak self] in
            self?.openSettings()
        }
        menuBar.onQuit = {
            NSApp.terminate(nil)
        }
    }

    private func configureNotifications() {
        // UNUserNotificationCenter requires a valid app bundle
        guard Bundle.main.bundleIdentifier != nil else {
            print("[DEBUG] Skipping notifications - not running as app bundle")
            return
        }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func startFocusDetection() {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now(), repeating: .seconds(2))
        timer.setEventHandler { [weak self] in
            self?.pollFocusState()
        }
        timer.resume()
        self.focusTimer = timer
    }

    private func pollFocusState() {
        guard settings.autoStart else {
            print("[DEBUG] autoStart is disabled")
            return
        }
        guard detector.isAccessibilityTrusted else {
            print("[DEBUG] Accessibility not trusted")
            return
        }
        guard let snapshot = detector.snapshot() else {
            print("[DEBUG] Could not get snapshot")
            return
        }

        // Ignore self - don't pause when user clicks our menu bar
        if snapshot.bundleId == "com.pomodoroauto.app" {
            return
        }

        cache.append(snapshot: snapshot)

        let runningBundleIds = detector.runningBundleIds()
        let allowlist = Set(settings.autoStartBundleIds)
        let runningAllowlistApps = allowlist.intersection(runningBundleIds)
        let isWork = !runningAllowlistApps.isEmpty
        
        print("[DEBUG] App: \(snapshot.bundleId), isWork: \(isWork), running allowlist apps: \(runningAllowlistApps)")
        if isWork {
            if !workTimer.isRunning && !breakTimer.isRunning {
                startTimer()
            }
        } else {
            if workTimer.isRunning {
                pauseTimer()
            }
        }
    }

    private func toggleRunning() {
        if breakTimer.isRunning {
            breakTimer.pause()
            startTimer()
            return
        }
        if workTimer.isRunning {
            pauseTimer()
        } else {
            startTimer()
        }
    }

    private func pauseTimer() {
        workTimer.pause()
        endActiveSessionAndFlush()
        state = .paused
        updateStatusTextForCurrentState()
    }

    private func resetTimer() {
        workTimer.reset()
        breakTimer.reset()
        endActiveSessionAndFlush()
        state = .idle
        updateStatusTextForCurrentState()
    }

    private func startTimer() {
        breakTimer.pause()
        beginActiveSessionIfNeeded()
        workTimer.start()
        state = .running
        updateStatusTextForCurrentState()
        sendWorkStartedNotification()
    }

    private func beginActiveSessionIfNeeded() {
        if activeSessionStart == nil {
            activeSessionStart = Date()
        }
    }

    private func endActiveSessionAndFlush() {
        if let start = activeSessionStart {
            let delta = max(0, Int(Date().timeIntervalSince(start)))
            accumulatedWorkSeconds += delta
            activeSessionStart = nil
        }
        flushActiveSession()
    }

    private func flushActiveSession() {
        guard accumulatedWorkSeconds > 0 else { return }
        statsStore.addWorkSeconds(accumulatedWorkSeconds)
        accumulatedWorkSeconds = 0
    }

    private func updateStatusTextForCurrentState() {
        switch state {
        case .running:
            menuBar.setTotalDuration(seconds: settings.workMinutes * 60)
            menuBar.setRemaining(seconds: workTimer.remainingSeconds, isBreak: false)
        case .paused:
            menuBar.setStatus(text: "Paused")
        case .completed:
            menuBar.setStatus(text: "Done")
        case .idle:
            menuBar.setStatus(text: "Idle")
        case .resting:
            menuBar.setTotalDuration(seconds: settings.breakMinutes * 60)
            menuBar.setRemaining(seconds: breakTimer.remainingSeconds, label: "Break", isBreak: true)
        }
    }

    private func sendCompletionNotification() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = "Pomodoro Complete"
        content.body = "Time for a break."
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func sendBreakStartedNotification() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = "Break Started"
        content.body = "Relax for a bit."
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func sendBreakEndedNotification() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = "Break Over"
        content.body = "Ready to start the next session."
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func sendWorkStartedNotification() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = "Pomodoro Started"
        content.body = "Focus time begins."
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(settings: settings, statsStore: statsStore) { [weak self] in
                self?.applySettings()
            }
        }
        if let window = settingsWindow?.window {
            positionWindowTopRight(window)
            window.alphaValue = 0
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)

            if #available(macOS 11.0, *) {
                window.level = .floating
            }

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().alphaValue = 1
            }
        }
    }

    private func openStats() {
        if statsWindow == nil {
            statsWindow = StatsWindowController(statsStore: statsStore)
        }
        statsWindow?.updateStats()
        if let window = statsWindow?.window {
            positionWindowTopRight(window)
            window.alphaValue = 0
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)

            if #available(macOS 11.0, *) {
                window.level = .floating
            }

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().alphaValue = 1
            }
        }
    }

    private func applySettings() {
        ruleEngine = RuleEngine(config: settings.ruleConfig)
        workTimer.setDuration(seconds: settings.workMinutes * 60)
        breakTimer.setDuration(seconds: settings.breakMinutes * 60)
        updateStatusTextForCurrentState()
    }

    private func startBreak() {
        breakTimer.start()
        state = .resting
        updateStatusTextForCurrentState()
        sendBreakStartedNotification()
    }

    private func positionWindowTopRight(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        let frame = window.frame
        let visibleFrame = screen.visibleFrame
        let margin: CGFloat = 16
        let originX = visibleFrame.maxX - frame.width - margin
        let originY = visibleFrame.maxY - frame.height - margin
        window.setFrameOrigin(NSPoint(x: originX, y: originY))
    }
}
