# AGENTS.md

This file provides context and guidelines for AI agents working on the PomodoroAuto codebase.

## 1. Build & Test Commands

### Build
```bash
swift build                        # Debug build
swift build -c release            # Release build
```

### Test
**Always run tests after modifying logic.**
```bash
swift test                        # Run all tests
swift test --filter <TestClass>   # Run specific test class
swift test --filter <TestClass>.<testMethod> # Run specific test case
```

Examples:
```bash
swift test --filter RuleEngineTests
swift test --filter RuleEngineTests.testAutoStartAllowlistBlocksOtherApps
```

### Linting
No linter is currently configured. Follow the code style guidelines below strictly.

## 2. Code Style & Conventions

### General
- **Indentation**: 4 spaces.
- **Access Control**: Use `private` for internal properties/methods. Default to internal.
- **Final Classes**: Mark classes as `final` unless inheritance is required.
- **Imports**: Alphabetical order. Group system frameworks (Foundation, AppKit) separately.

### Naming
- **Types**: `PascalCase` (e.g., `PomodoroTimer`, `MenuBarController`).
- **Variables/Functions**: `camelCase` (e.g., `remainingSeconds`, `startTimer`).
- **Constants**: `camelCase`, typically inside a `private enum Keys` or similar namespace.
- **Test Methods**: `test` prefix + `CamelCase` (e.g., `testTimerResetsCorrectly`).

### Memory Management (CRITICAL)
- **Weak Self**: Always use `[weak self]` in closures (timers, callbacks, notifications) to avoid retain cycles.
- **Guard Self**: Use `guard let self = self else { return }` at the start of closures if `self` is required.

```swift
timer.setEventHandler { [weak self] in
    guard let self = self else { return }
    self.tick()
}
```

### Error Handling
- **Guard**: Use `guard` for early exits and precondition checks.
- **Optionals**: Prefer optional binding (`if let`, `guard let`) over force unwrapping (`!`).
- **Defaults**: Use `??` for default values.

## 3. Architecture & Patterns

### Core Components
- **PomodoroTimer**: Handles the countdown logic using `DispatchSourceTimer`.
- **RuleEngine**: Determines if the current state is "Work" or "Rest" based on active apps/windows.
- **MenuBarController**: Manages the macOS menu bar UI (NSStatusItem).

### Data Flow
1. **Timer** ticks every second.
2. **FocusStateDetector** checks the frontmost app.
3. **RuleEngine** evaluates if it's work or distraction.
4. **PomodoroTimer** updates state (Running/Paused).
5. **MenuBarController** updates the UI.

### UserDefaults Pattern
Encapsulate keys and accessors:
```swift
private enum Keys {
    static let workMinutes = "workMinutes"
}
var workMinutes: Int {
    get { UserDefaults.standard.integer(forKey: Keys.workMinutes) }
    set { UserDefaults.standard.set(newValue, forKey: Keys.workMinutes) }
}
```

### UI Development (AppKit)
- **Programmatic UI**: Prefer code over XIB/Storyboards.
- **Auto Layout**: Use `NSLayoutConstraint.activate([...])`.
- **System Icons**: Use `NSImage(systemSymbolName: ...)` (SF Symbols).

## 4. Project Structure

- `Sources/Core/`: Business logic (Timer, Rules, State).
- `Sources/App/`: UI and Application lifecycle (AppDelegate, MenuBar).
- `Sources/Data/`: Persistence (UserDefaults, FileSystem).
- `Tests/PomodoroAutoTests/`: Unit tests mirroring the source structure.

## 5. Agent Behavior Guidelines

1. **Verify Changes**: Run relevant tests after every change.
2. **Keep It Simple**: Do not over-engineer. Follow existing patterns.
3. **No Screen Recording**: The app uses Accessibility APIs, not screen recording. Do not suggest screen recording permissions.
4. **Swift 5.9+**: Use modern Swift concurrency features if applicable, but stick to DispatchSourceTimer for precise timing as currently implemented.
