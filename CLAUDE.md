# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
swift build                # Debug build
swift build -c release     # Release build
swift test                 # Run all tests
./build-app.sh             # Release build + create .app bundle with Info.plist and icon
open VideoNotes.app        # Launch the built app
```

Open `Package.swift` in Xcode for IDE development (Cmd+R to run).

The project targets **macOS 14+ (Sonoma)** with no external dependencies — pure SwiftUI, AVKit, AVFoundation, Speech, PDFKit.

## Architecture

**MVVM + Services** pattern. ContentView is the root coordinator that owns all state:

```
ContentView (@StateObject owners)
├── PlayerViewModel      — AVPlayer lifecycle, playback, periodic timecode updates
├── SessionViewModel     — Note CRUD, session save/load (.videonotes JSON files)
├── KeyEventHandler      — NSEvent monitor for auto-pause typing detection
└── SpeechService        — Live speech-to-text via Apple Speech framework
```

Note: `AppState` exists but is unused — ContentView creates its own ViewModels directly.

### Key Interaction Flows

**Typing a note**: KeyEventHandler intercepts printable key → optionally pauses video → creates note with current timecode → **stops the monitor** so TextField receives keystrokes → on Enter/Esc, restarts monitor. The start/stop pattern is critical — the NSEvent monitor eats keystrokes before SwiftUI TextFields if left running.

**Voice mode**: SpeechService captures video timecode on first partial result (with -0.5s latency offset), accumulates transcript, commits note after 1.5s silence, then auto-restarts a fresh recognition session. Uses an `isRestarting` flag to suppress error callbacks during intentional teardown (cancelling a recognition task triggers error callbacks that would otherwise cause infinite restart loops).

**Auto-pause vs no auto-pause**: Both modes open the note overlay on typing. The `wasPausedByAutoPause` flag tracks whether we paused the video, so commit/cancel only resumes playback if auto-pause caused the pause.

### Review Mode

Immersive fullscreen-like layout toggled via Cmd+Shift+F. Entering macOS native fullscreen also activates review mode automatically (`FullscreenWindowObserver`). The system has two layers:

1. **In-app chrome** (review top/bottom bars) — controlled by `isReviewChromeVisible` + `shouldKeepReviewChromeVisible`. Auto-hides after 2.5s, re-reveals on tap or when editing/listening/error states are active.
2. **macOS toolbar** — hidden via `ReviewModeWindowConfigurator` (an `NSViewRepresentable` that manipulates `NSWindow` properties). Auto-reveals when the mouse enters the top edge of the window, hides when it moves away.

Chrome stays visible when `shouldKeepReviewChromeVisible` is true (editing, listening, notes panel open, errors). The `reviewChromeHideTask` handles the delayed hide and is cancelled/restarted as conditions change.

### Export System

Protocol-based: `NoteExporter` with 5 implementations. Each calculates out-timecodes differently per NLE semantics:
- Avid SubCap: out = in + 1 second (subtitle duration)
- Premiere CSV / Resolve EDL: out = in + 1 frame (point marker)

### Timecode System

`TimecodeInfo` handles HH:MM:SS:FF conversion including drop-frame math (29.97/59.94fps). Drop-frame uses 10-minute block compensation. The periodic time observer updates at ~30fps — not frame-accurate but sufficient for UI display.

### Persistence

Sessions save as `.videonotes` JSON files. Video file references use **security-scoped bookmarks** (`URL.bookmarkData(options: .withSecurityScope)`) to maintain file access across app restarts.

### TransparentPlayerView

Custom `AVPlayerView` subclass that recursively clears black backgrounds from all internal sublayers on every layout pass, preserving only the `AVPlayerLayer`. This lets the app's gradient background show through letterbox areas.

## Testing

Tests cover timecode math (various frame rates, drop-frame format) and all 5 exporters (output validation, UTF-8 BOM for Avid, PDF header check). No tests for SpeechService, KeyEventHandler, or PlayerViewModel as they require system integration.

## Non-Obvious Gotchas

- **KeyEventHandler must be stopped during editing** — otherwise the NSEvent monitor intercepts keys before the SwiftUI TextField
- **SpeechService restart flag** — `isRestarting` prevents cascading restarts from error callbacks triggered by `recognitionTask?.cancel()`
- **Speech cancellation error codes 216/209** are expected and must be ignored
- **Frame rate detection** uses a heuristic: if nominalRate ≈ 29.97 (within 0.1 of 30), it's marked as drop-frame
- **Theme.swift** defines all shared colors, gradients, and the `.glassCard()` modifier — use it for consistent styling
- **ReviewModeWindowConfigurator** uses a local NSEvent mouse-move monitor — it must be removed on deinit and only active during review mode to avoid leaking event monitors
- **ContentView is large** (~1200 lines) — it owns both standard and review mode layouts plus all coordination logic. When editing, read the relevant section rather than the whole file
