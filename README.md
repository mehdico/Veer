# Veer

A native SwiftUI clipboard manager for macOS. Clean-room rewrite of [Yippy](../Yippy/) on a modern stack: SwiftUI + SwiftData + `@Observable` + Swift Testing.

## Features

- Menu-bar resident, no dock icon (`LSUIElement`).
- Global ⌘⇧V toggles a floating panel over any app.
- Captures everything you copy (text, RTF, HTML, PNG, TIFF, PDF, file URLs, NSColor) with per-app source tracking.
- Fuzzy search across history, live as you type.
- Floating preview window (Spacebar) for full-fidelity text / image / color / PDF / file rendering.
- 11 panel positions with `⌃⌥⌘ + arrow` shortcuts; vertical list + horizontal card strip layouts.
- ⌘0 … ⌘9 quick-paste; ⌃⌫ delete selected; Esc closes.
- Launch-at-login via `SMAppService`.

## Requirements

- macOS 15 Sequoia or later
- Xcode 16 or later
- Accessibility permission (System Settings → Privacy & Security → Accessibility)

## Build & run

Open `Veer.xcodeproj` and run the **Veer** scheme. On first launch, a Welcome window asks for Accessibility access — that's required for the global hotkey and for simulating ⌘V into the previous app.

```bash
xcodebuild -project Veer.xcodeproj -scheme Veer -destination 'platform=macOS' build
```

## Run tests

Unit tests (Swift Testing):

```bash
xcodebuild -project Veer.xcodeproj -scheme Veer -destination 'platform=macOS' \
  -only-testing:VeerTests test
```

UI tests (XCUITest, requires Accessibility access for the test runner):

```bash
xcodebuild -project Veer.xcodeproj -scheme Veer -destination 'platform=macOS' \
  -only-testing:VeerUITests test
```

UI tests launch with `--uitesting`, swapping in an in-memory store, a no-op hotkey service, and a `CountingPaster`. Add `--seed=mixed` to pre-populate one item per cell type, or `--mock-trusted=false` to simulate missing Accessibility permission.

## Project layout

```
Veer/
├── App/                — VeerApp, AppDelegate, AppEnvironment (DI), LaunchArguments
├── Core/
│   ├── Constants/      — Constants, AccessibilityIdentifiers
│   ├── Errors/         — Alerter (NSAlert wrapper)
│   └── Logging/        — VeerLogger (OSLog wrapper)
├── Domain/Models/      — ClipPayload, ClipItemSnapshot, CellKind, PanelPosition
├── Persistence/        — ClipItem / PayloadBlob @Model, ClipRepository(Live), ModelContainer factories
├── Services/
│   ├── Hotkeys/        — Carbon-backed global hotkey service
│   ├── LaunchAtLogin/  — SMAppService wrapper
│   ├── Paste/          — CGEvent paste + pasteboard writer
│   ├── Pasteboard/     — 50ms NSPasteboard monitor + ingestor
│   ├── Permissions/    — AXIsProcessTrusted wrapper
│   ├── Search/         — Fuse-style fuzzy search engine
│   └── Settings/       — VeerSettings + UserDefaults-backed store
├── Features/
│   ├── About/          — About window
│   ├── Help/           — Help window
│   ├── HistoryPanel/   — Panel window/coordinator + list & card-strip views + cell variants
│   ├── Preview/        — Preview window/coordinator + variants (text, image, pdf, color, file)
│   ├── Settings/       — Settings scene (General + Hotkeys tabs)
│   ├── StatusBar/      — NSStatusItem + menu builder
│   └── Welcome/        — Accessibility-permission onboarding
└── UITestSupport/      — In-memory seeders for UI tests (gated by --uitesting)
```

## Architecture notes

- **State**: native `@Observable` macro for view models; `AsyncStream` for repository change events.
- **DI**: a single `AppEnvironment` is built in `AppDelegate.applicationDidFinishLaunching` and threaded through all subsystems. No singletons.
- **Persistence**: SwiftData `@Model` types. Big binary blobs (images, RTF, PDF) use `@Attribute(.externalStorage)`. Small inline `preview` (text) and `thumbnailPNG` are denormalized onto `ClipItem` for fast cell rendering.
- **Floating panel**: `NSPanel` subclass (`canBecomeKey`, `nonactivatingPanel`, custom `constrainFrameRect`) hosting SwiftUI via `NSHostingView`, driven by an `@Observable` `PanelCoordinator`. The pure SwiftUI scene types (`Window`, `MenuBarExtra`) couldn't override `styleMask`/`level` deeply enough.
- **Hotkeys**: small Carbon `RegisterEventHotKey` wrapper behind a `HotkeyService` protocol; mocked in tests.
- **Paste**: `PasteSimulating` protocol fronts `CGEventPaster` (live) and `MockPaster` / `CountingPaster` (tests). Reactivates the previous frontmost app and posts ⌘V on a 50 ms delay so the keystroke lands in the right window.

## Testing

- **Unit** with Swift Testing (`@Test`, `#expect`). Each test gets a fresh in-memory `ModelContainer`. Mocks live in `VeerTests/Mocks/`.
- **UI** with XCTest / XCUITest. App is launched with `--uitesting` so the env swaps to in-memory store + safe mocks. Every interactive element carries an accessibility identifier defined in `Veer/Core/Constants/AccessibilityIdentifiers.swift`.

## Status

Built incrementally in 11 phases, each shipping a green build + tests. Current totals: 92 unit tests passing, 18 UI test cases across 9 files. Outstanding follow-ups: a live hotkey recorder (the bindings are fixed defaults), localization scaffolding, and a VoiceOver audit.
