# VideoNotes

A native macOS app for taking timestamped notes while reviewing video. Type or speak — every note is automatically tagged with the video timecode.

Built with SwiftUI + AVKit. No external dependencies.

## Features

**Timestamped Note-Taking**
- Start typing while a video plays and a note is created at the current timecode
- Auto-pause mode pauses the video when you type, resumes when you hit Enter
- With auto-pause off, the video keeps playing while you write

**Voice Mode**
- Toggle the mic to dictate notes hands-free
- Video keeps playing while you speak
- Notes are timestamped when speech starts (with latency compensation)
- Powered by Apple's Speech framework — all processing on-device

**Export to NLE Markers**
| Format | File | Use With |
|--------|------|----------|
| Plain Text | `.txt` | Any text editor |
| PDF | `.pdf` | Sharing / print |
| Avid SubCap | `.txt` | Avid Media Composer (Tools > Marker Tool > Import) |
| Premiere CSV | `.csv` | Adobe Premiere Pro (via Marker Converter / Markerbox) |
| Resolve EDL | `.edl` | DaVinci Resolve (Timelines > Import > Timeline Markers from EDL) |

**Session Persistence**
- Save/reopen `.videonotes` files to continue reviewing or re-export later
- Video file references stored as security-scoped bookmarks

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15+ (to build)
- Microphone access (for voice mode)

## Build & Run

```bash
# Build
swift build

# Run the app
./build-app.sh && open VideoNotes.app
```

Or open `Package.swift` in Xcode and press **Cmd+R**.

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Space` | Play / Pause |
| `Cmd+O` | Open video file |
| `Cmd+N` | Add note manually |
| `Cmd+E` | Export notes |
| `Enter` | Commit note |
| `Esc` | Cancel note |
| Any key | Start a new note (when video has focus) |

## Supported Formats

Plays anything AVFoundation supports natively: **ProRes**, **H.264**, **H.265** (`.mov`, `.mp4`, `.m4v`).

DNxHD/DNxHR requires [Avid codecs](https://www.avid.com/products/avid-codecs) installed on the system.

## Project Structure

```
Sources/VideoNotes/
├── App/                    # Entry point, shared state
├── Models/                 # Note, Session, TimecodeInfo
├── Views/                  # SwiftUI views
├── ViewModels/             # Player + session logic
├── Services/               # Exporters, speech, timecode extraction
└── Utilities/              # Theme, key handling, CMTime extensions
```

## License

MIT
