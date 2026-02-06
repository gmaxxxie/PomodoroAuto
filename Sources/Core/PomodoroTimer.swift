import Foundation

final class PomodoroTimer {
    private var timer: DispatchSourceTimer?
    private(set) var durationSeconds: Int
    private(set) var remainingSeconds: Int
    private(set) var isRunning = false

    var onTick: ((Int) -> Void)?
    var onComplete: (() -> Void)?

    init(durationSeconds: Int) {
        self.durationSeconds = max(1, durationSeconds)
        self.remainingSeconds = max(1, durationSeconds)
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now() + 1, repeating: .seconds(1))
        timer.setEventHandler { [weak self] in
            self?.tick()
        }
        timer.resume()
        self.timer = timer
    }

    func pause() {
        isRunning = false
        timer?.cancel()
        timer = nil
    }

    func reset() {
        pause()
        remainingSeconds = durationSeconds
    }

    func setDuration(seconds: Int) {
        let newDuration = max(1, seconds)
        durationSeconds = newDuration
        if isRunning {
            remainingSeconds = min(remainingSeconds, newDuration)
            if remainingSeconds == 0 {
                complete()
            }
        } else {
            remainingSeconds = newDuration
        }
    }

    private func tick() {
        guard isRunning else { return }
        remainingSeconds = max(0, remainingSeconds - 1)
        onTick?(remainingSeconds)
        if remainingSeconds == 0 {
            complete()
        }
    }

    private func complete() {
        pause()
        remainingSeconds = durationSeconds
        onComplete?()
    }
}
