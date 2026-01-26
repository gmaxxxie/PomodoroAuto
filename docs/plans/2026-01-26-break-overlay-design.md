# Break Overlay Design (2026-01-26)

## Goal
Make the end-of-work timer alert significantly more noticeable by showing a full-screen dim overlay on the main display with a centered rest message. The overlay should be dismissible via ESC or automatically after 15 seconds. It should only appear when a work session ends and a break starts. System notifications remain for now.

## Scope
- Show overlay only at work completion (entering break).
- Main display only.
- ESC to dismiss; auto-dismiss after 15 seconds.
- Randomized tip text from a fixed set of 10 localized prompts (zh-Hans + en).

## Proposed Components
1) `BreakOverlayWindowController`
- Creates a borderless transparent window attached to `NSScreen.main`.
- Window level: `.screenSaver` for topmost visibility.
- `collectionBehavior`: `.canJoinAllSpaces` + `.fullScreenAuxiliary`.
- Overrides `canBecomeKey`/`canBecomeMain` to receive ESC.
- Public API: `show(title:message:footer:timeoutSeconds:)` and `dismiss()`.

2) `BreakOverlayView`
- Root view with semi-transparent black background.
- Centered `NSStackView` with title, message, and ESC hint.
- Basic fade-in animation.

3) `BreakPromptProvider`
- Holds localized keys for 10 prompt messages.
- Returns a random prompt string via `randomPrompt()` with a safe fallback.

## Data Flow
- `workTimer.onComplete` -> `startBreak()` -> `showBreakOverlay()`.
- `showBreakOverlay()` picks a localized title/body and shows the overlay.
- User dismisses via ESC or overlay auto-dismisses after 15 seconds.

## Localization
Add keys in both:
- `Sources/Resources/en.lproj/Localizable.strings`
- `Sources/Resources/zh-Hans.lproj/Localizable.strings`

Keys:
- `overlay.break.title`
- `overlay.break.dismiss`
- `overlay.break.prompt.1` ... `overlay.break.prompt.10`

## Error Handling
- If `NSScreen.main` is nil, skip overlay gracefully (no crash).
- If overlay fails to show, system notification still fires.

## Testing
- Unit test for `BreakPromptProvider` to assert 10 keys exist and returned prompt is non-empty.
- Manual: complete a work session -> overlay appears on main display -> ESC/timeout dismisses.
