# Veer

A native SwiftUI clipboard manager for macOS. Inspired by [Yippy](../Yippy/), built on a modern stack: SwiftUI + SwiftData + `@Observable` + Swift Testing.

## Features

- Menu-bar resident, no dock icon (`LSUIElement`).
- Global ⌘⇧V toggles a floating panel over any app.
- Captures everything you copy (text, RTF, HTML, PNG, TIFF, PDF, file URLs, NSColor) with per-app source tracking.
- Password managers and Keychain Access are ignored by default — a Settings → Ignored apps toggle, on by default, with per-app opt-outs.
- Fuzzy search across history, live as you type.
- Floating preview window (Spacebar) for full-fidelity text / image / color / PDF / file rendering.
- On-clip content previews — image, PDF, and file thumbnails plus color swatches render right on the history cells; plain-text clips that are exactly a hex color (3, 6, or 8 digits, optional leading `#`) get a swatch with the hex readout. Toggleable via Settings → General → Appearance → Show previews in clips (on by default; off shows icons + labels).
- Smart actions — clips get an inline action strip (↓ opens it in both card and list layouts and closes it again; ←/→ move between the actions while it's open; Return runs the highlighted action, ⌘↩ the first). Text clips that are a URL (including git hosts), email, phone number, hex color, coordinate pair, JSON, arithmetic expression, ISO date, git SSH URL, or existing absolute path get tailored actions: open-in-browser, compose email, call, copy-as-Markdown-link / Swift `Color`, open-in-Maps, copy-math-result, pretty-print/minify JSON, copy-epoch-seconds, copy-git-clone, reveal/open in Finder. File and folder clips get Reveal in Finder, Open, Copy Path, Copy File, Copy as Markdown Link, Open in Terminal (folders), Open in Xcode (.swift/.xcodeproj/.xcworkspace/.playground). Images get Save to Downloads and Copy as PNG; PDFs Save to Downloads; NSColor clips get Copy as Hex / CSS rgb() / UIColor; rich text gets Copy as Plain Text. Non-English prose gets Translate to English when its language pack is installed (macOS 26+), and unrecognized text can get Search the Web via a Settings → General → Smart Actions toggle.
- 11 panel positions with `⌃⌥⌘ + arrow` shortcuts; vertical list + horizontal card strip layouts.
- ⌘1 … ⌘9 quick-paste; ⌃⌫ delete selected; Esc closes.
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

UI tests launch with `--uitesting`, swapping in an in-memory store, a no-op hotkey service, and a `CountingPaster`. Add `--seed=mixed` to pre-populate one item per cell type, `--seed=smartActions` to seed URL and hex-color clips for the smart-action tests, or `--mock-trusted=false` to simulate missing Accessibility permission.

## Project layout

```
Veer/
├── App/                — VeerApp, AppDelegate, AppEnvironment (DI), LaunchArguments
├── Core/
│   ├── Constants/      — Constants, AccessibilityIdentifiers
│   ├── Errors/         — Alerter (NSAlert wrapper)
│   └── Logging/        — VeerLogger (OSLog wrapper)
├── Domain/Models/      — ClipPayload, ClipItemSnapshot, CellKind, PanelPosition, ClipAction, ClipContentDetector
├── Persistence/        — ClipItem / PayloadBlob @Model, ClipRepository(Live), ModelContainer factories
├── Services/
│   ├── ClipActions/    — ClipActionRunner (NSWorkspace handoff + pasteboard copies)
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
│   ├── Settings/       — Settings scene (General + Ignored Apps + Shortcuts tabs)
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

Version 1.6.0. Built incrementally, each phase shipping a green build + tests. Current totals: 232 unit tests and 23 UI test cases across 14 files (counts as declared in the test sources; run the test commands above to verify). Outstanding follow-ups: a live hotkey recorder (the bindings are fixed defaults), localization scaffolding, and a VoiceOver audit.
