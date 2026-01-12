# AGENTS.md

This file provides guidance for agentic coding assistants working on the PomodoroAuto codebase.

## Build, Test, and Lint Commands

### Build
```bash
swift build                      # Build the project
swift build --configuration release   # Release build
```

### Test
```bash
swift test                       # Run all tests
swift test --filter TestClassName.testMethodName  # Run single test
swift test --verbose             # Run with verbose output
```

Examples:
```bash
swift test --filter RuleEngineTests.testAutoStartAllowlistBlocksOtherApps
swift test --filter StatsStoreTests
```

### Lint
No linting tools are currently configured. If adding linting, consider SwiftLint.

## Code Style Guidelines

### Imports
- Organize imports alphabetically
- No unused imports
- Group by platform (Foundation, AppKit, etc.) when multiple imports exist

### Types and Classes
- Use `final class` for classes that don't need inheritance
- Use `struct` for data models and value types
- Use private init? = nil for unsupported NSCoder conformance in NSWindowController

### Naming Conventions
- **Functions/Variables**: `camelCase` (e.g., `handleSave`, `workTimer`)
- **Types**: `PascalCase` (e.g., `MenuBarController`, `RuleConfig`)
- **Constants/Keys**: `camelCase` within private enum (e.g., `Keys.workMinutes`)
- **Test Methods**: `camelCase` prefixed with `test` (e.g., `testAutoStartAllowlistBlocksOtherApps`)

### Formatting
- Use 4 spaces for indentation (Swift default)
- No trailing whitespace
- Default access control is preferred for internal members
- Private members should be explicitly marked `private`
- Use guard statements for early exits and validation
- Avoid force unwrapping (!) unless safe; prefer optional binding

### Error Handling
- Use `guard` statements for precondition validation
- Return early from functions when invalid state is detected
- Use optional binding (`if let`, `guard let`) for unwrapping
- Use `??` operator for default values with optionals

### Memory Management
- Always use `[weak self]` in closures to prevent retain cycles
- Capture lists: `timer.setEventHandler { [weak self] in ... }`
- Use `guard let self = self else { return }` pattern when needed

### Code Organization
- Sources organized by feature: `Core/`, `App/`, `Data/`
- Related types grouped in files by domain
- Tests mirror source structure in `Tests/PomodoroAutoTests/`

### UserDefaults Pattern
```swift
private enum Keys {
    static let settingName = "settingName"
}

private let defaults = UserDefaults.standard

var settingName: Type {
    get { defaults.type(forKey: Keys.settingName) }
    set { defaults.set(newValue, forKey: Keys.settingName) }
}

init() {
    defaults.register(defaults: [Keys.settingName: defaultValue])
}
```

### Dependency Injection
- Inject dependencies via init for testability
- Default parameters can use standard implementations:
```swift
init(defaults: UserDefaults = .standard, key: String = "statsByDay")
```

### Timer and Async Operations
- Use `DispatchSourceTimer` for recurring timers
- Schedule on `DispatchQueue.main` for UI updates
```swift
let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
timer.schedule(deadline: .now() + 1, repeating: .seconds(1))
timer.setEventHandler { [weak self] in ... }
timer.resume()
```

### Callback Pattern
Use optional closure properties for event callbacks:
```swift
var onTick: ((Int) -> Void)?
var onComplete: (() -> Void)?
```

### Testing
- Use XCTest framework
- Import with `@testable import PomodoroAuto`
- Use isolated UserDefaults for tests:
```swift
let suiteName = "PomodoroAutoTests.StatsStore"
let defaults = UserDefaults(suiteName: suiteName)!
defaults.removePersistentDomain(forName: suiteName)
```

### Accessibility and macOS APIs
- Request accessibility permissions before using AX APIs
- Check trust with `AXIsProcessTrusted()`
- Use ApplicationServices framework for AX APIs
- Get frontmost app with `NSWorkspace.shared.frontmostApplication`

### UI Components
- Use NSStackView for layout
- Use Auto Layout constraints with `translatesAutoresizingMaskIntoConstraints = false`
- Window positioning uses `screen.visibleFrame` and margins
- System icons via `NSImage(systemSymbolName:accessibilityDescription:)`

### Notifications
- Use UNUserNotificationCenter for system notifications
- Set delegate to handle foreground presentation
- Request authorization at app launch

## Project Structure

- `Sources/Core/` - Core logic: timer, state detection, rule engine
- `Sources/App/` - UI: menu bar, windows, app delegate
- `Sources/Data/` - Persistence: settings, stats, cache
- `Tests/PomodoroAutoTests/` - Unit tests

## Key Design Decisions

- No screen recording - only reads foreground window state via Accessibility API
- State machine: Idle, Running, Paused, Completed, Resting
- Stats stored by date key (YYYY-MM-DD) in UserDefaults
- FIFO cache with retention limits for state snapshots
- Safari fullscreen always treated as non-work (hardcoded rule)
