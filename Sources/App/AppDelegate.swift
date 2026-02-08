import AppKit
import Foundation
import UserNotifications
import QuartzCore
import os.log

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "PomodoroAuto", category: "AppDelegate")
    static let shouldRequestAccessibilityAccessOnLaunch = false
    static let shouldRequestNotificationAuthorizationOnLaunch = false
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
    private let workTimer: PomodoroTimer
    private let breakTimer: PomodoroTimer
    private let menuBar: MenuBarController
    
    private var settingsWindow: SettingsWindowController?
    private var statsWindow: StatsWindowController?
    private var breakOverlay: BreakOverlayWindowController?
    private var continuationPrompt: ContinuationPromptWindowController?
    private var focusTimer: DispatchSourceTimer?
    private var activeSessionStart: Date?
    private var accumulatedWorkSeconds = 0
    private var isAutoStartSuppressed = false
    private var state: SessionState = .idle

    override init() {
        Localization.apply(preference: settings.languagePreference)
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
        if Self.shouldRequestAccessibilityAccessOnLaunch && Self.shouldPromptAccessibilityAccess(
            autoStartEnabled: settings.autoStart,
            isAccessibilityTrusted: detector.isAccessibilityTrusted
        ) {
            _ = detector.requestAccess()
        }
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
            self.menuBar.setRemaining(seconds: remaining, label: Localization.localized("menu.status.break"), isBreak: true)
            self.breakOverlay?.updateCountdown(seconds: remaining)
        }

        breakTimer.onComplete = { [weak self] in
            guard let self else { return }
            self.isAutoStartSuppressed = true
            self.state = .paused
            self.updateStatusTextForCurrentState()
            self.sendBreakEndedNotification()
            self.showContinuationPrompt()
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
        guard Bundle.main.bundleIdentifier != nil else {
            Self.logger.info("Skipping notifications - not running as app bundle")
            return
        }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        
        let startNextAction = UNNotificationAction(
            identifier: "START_NEXT",
            title: Localization.localized("notification.action.startNext"),
            options: [.foreground]
        )
        let stopAction = UNNotificationAction(
            identifier: "STOP",
            title: Localization.localized("notification.action.stop"),
            options: []
        )
        
        let breakEndedCategory = UNNotificationCategory(
            identifier: "BREAK_ENDED",
            actions: [startNextAction, stopAction],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([breakEndedCategory])
        if Self.shouldRequestNotificationAuthorizationOnLaunch {
            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
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
            Self.logger.debug("autoStart is disabled")
            return
        }
        guard detector.isAccessibilityTrusted else {
            Self.logger.debug("Accessibility not trusted")
            return
        }
        guard let snapshot = detector.snapshot() else {
            Self.logger.debug("Could not get snapshot")
            return
        }

        let allowlistBundleIds = settings.autoStartBundleIds
        let runningAllowlistApps = detector.runningAllowlistBundleIds(from: allowlistBundleIds)
        guard let isWork = Self.evaluateWorkState(
            snapshot: snapshot,
            appBundleId: Bundle.main.bundleIdentifier,
            runningAllowlistApps: runningAllowlistApps,
            ruleEngine: ruleEngine
        ) else {
            return
        }
        isAutoStartSuppressed = Self.nextAutoStartSuppressionState(
            currentlySuppressed: isAutoStartSuppressed,
            isWork: isWork
        )
        
        Self.logger.debug("App: \(snapshot.bundleId), isWork: \(isWork), auto-start suppressed: \(self.isAutoStartSuppressed)")
        if isWork {
            if Self.shouldStartTimer(
                isWork: isWork,
                workTimerRunning: workTimer.isRunning,
                breakTimerRunning: breakTimer.isRunning,
                isAutoStartSuppressed: isAutoStartSuppressed
            ) {
                startTimer()
            }
        } else if Self.shouldPauseWorkTimer(
            isWork: isWork,
            workTimerRunning: workTimer.isRunning
        ) {
            pauseTimer()
        }
    }

    static func shouldPromptAccessibilityAccess(
        autoStartEnabled: Bool,
        isAccessibilityTrusted: Bool
    ) -> Bool {
        autoStartEnabled && !isAccessibilityTrusted
    }

    static func evaluateWorkState(
        snapshot: FocusSnapshot,
        appBundleId: String?,
        runningAllowlistApps: Set<String>,
        ruleEngine: RuleEngine
    ) -> Bool? {
        if snapshot.bundleId == appBundleId && runningAllowlistApps.isEmpty {
            return nil
        }
        return ruleEngine.isWork(snapshot: snapshot, runningAllowlistApps: runningAllowlistApps)
    }

    static func shouldStartTimer(
        isWork: Bool,
        workTimerRunning: Bool,
        breakTimerRunning: Bool,
        isAutoStartSuppressed: Bool
    ) -> Bool {
        isWork && !workTimerRunning && !breakTimerRunning && !isAutoStartSuppressed
    }

    static func nextAutoStartSuppressionState(
        currentlySuppressed: Bool,
        isWork: Bool
    ) -> Bool {
        // Clear suppression once the user leaves work context, so auto-start can recover on return.
        currentlySuppressed && isWork
    }

    static func shouldPauseWorkTimer(
        isWork: Bool,
        workTimerRunning: Bool
    ) -> Bool {
        !isWork && workTimerRunning
    }

    private func toggleRunning() {
        if breakTimer.isRunning {
            breakTimer.pause()
            startTimer()
            return
        }
        if workTimer.isRunning {
            pauseTimerAndSuppressAutoStart()
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

    private func pauseTimerAndSuppressAutoStart() {
        isAutoStartSuppressed = true
        pauseTimer()
    }

    private func resetTimer() {
        workTimer.reset()
        breakTimer.reset()
        endActiveSessionAndFlush()
        state = .idle
        updateStatusTextForCurrentState()
    }

    private func startTimer() {
        isAutoStartSuppressed = false
        breakTimer.pause()
        beginActiveSessionIfNeeded()
        workTimer.start()
        state = .running
        updateStatusTextForCurrentState()
        sendWorkStartedNotification()
    }

    private func stopAndSuppressAutoStart() {
        isAutoStartSuppressed = true
        resetTimer()
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
            menuBar.setStatus(text: Localization.localized("menu.status.paused"), mode: .paused)
        case .completed:
            menuBar.setStatus(text: Localization.localized("menu.status.done"), mode: .idle)
        case .idle:
            menuBar.setStatus(text: Localization.localized("menu.status.idle"), mode: .idle)
        case .resting:
            menuBar.setTotalDuration(seconds: settings.breakMinutes * 60)
            menuBar.setRemaining(seconds: breakTimer.remainingSeconds, label: Localization.localized("menu.status.break"), isBreak: true)
        }
    }

    private func sendCompletionNotification() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = Localization.localized("notification.pomodoroComplete.title")
        content.body = Localization.localized("notification.pomodoroComplete.body")
        content.sound = .default
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
        content.title = Localization.localized("notification.breakStarted.title")
        content.body = Localization.localized("notification.breakStarted.body")
        content.sound = .default
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
        content.title = Localization.localized("notification.breakEnded.title")
        content.body = Localization.localized("notification.breakEnded.body")
        content.sound = .default
        content.categoryIdentifier = "BREAK_ENDED"
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
        content.title = Localization.localized("notification.pomodoroStarted.title")
        content.body = Localization.localized("notification.pomodoroStarted.body")
        content.sound = .default
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

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case "START_NEXT":
            DispatchQueue.main.async { [weak self] in
                self?.startTimer()
            }
        case "STOP":
            DispatchQueue.main.async { [weak self] in
                self?.stopAndSuppressAutoStart()
            }
        default:
            break
        }
        completionHandler()
    }

    private func openSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(settings: settings, statsStore: statsStore) { [weak self] in
                self?.applySettings()
            }
            settingsWindow?.onClose = { [weak self] in
                self?.settingsWindow = nil
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
            statsWindow?.onClose = { [weak self] in
                self?.statsWindow = nil
            }
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
        if Self.shouldPromptAccessibilityAccess(
            autoStartEnabled: settings.autoStart,
            isAccessibilityTrusted: detector.isAccessibilityTrusted
        ) {
            _ = detector.requestAccess()
        }
        workTimer.setDuration(seconds: settings.workMinutes * 60)
        breakTimer.setDuration(seconds: settings.breakMinutes * 60)
        applyLocalization()
        updateStatusTextForCurrentState()
    }

    private func applyLocalization() {
        Localization.apply(preference: settings.languagePreference)
        menuBar.refreshLocalizedStrings()
        settingsWindow?.close()
        settingsWindow = nil
        statsWindow?.applyLocalization()
    }

    private func startBreak() {
        breakTimer.reset()
        breakTimer.start()
        state = .resting
        updateStatusTextForCurrentState()
        sendBreakStartedNotification()
        showBreakOverlay()
    }

    private func showBreakOverlay() {
        guard NSScreen.main != nil else { return }
        let prompt = BreakPromptProvider.randomPrompt()
        breakOverlay = BreakOverlayWindowController()
        breakOverlay?.onDismiss = { [weak self] in
            self?.breakOverlay = nil
        }
        breakOverlay?.onSkipBreak = { [weak self] in
            guard let self else { return }
            self.breakTimer.pause()
            self.startTimer()
        }
        breakOverlay?.updateCountdown(seconds: settings.breakMinutes * 60)
        breakOverlay?.show(
            title: Localization.localized("overlay.break.title"),
            message: prompt,
            footer: Localization.localized("overlay.break.dismiss"),
            closeTitle: Localization.localized("overlay.break.close"),
            timeoutSeconds: 30
        )
    }

    private func showContinuationPrompt() {
        guard NSScreen.main != nil else { return }
        breakOverlay?.dismiss()
        
        continuationPrompt = ContinuationPromptWindowController()
        continuationPrompt?.onStartNext = { [weak self] in
            guard let self else { return }
            self.continuationPrompt = nil
            self.startTimer()
        }
        continuationPrompt?.onStop = { [weak self] in
            guard let self else { return }
            self.continuationPrompt = nil
            self.stopAndSuppressAutoStart()
        }
        continuationPrompt?.show(
            title: Localization.localized("overlay.continuation.title"),
            message: Localization.localized("overlay.continuation.message"),
            startNextTitle: Localization.localized("overlay.continuation.startNext"),
            stopTitle: Localization.localized("overlay.continuation.stop")
        )
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
    
    func applicationWillTerminate(_ notification: Notification) {
        focusTimer?.cancel()
        workTimer.pause()
        breakTimer.pause()
    }
}
