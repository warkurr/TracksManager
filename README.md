# TracksManager

Native macOS application for managing MKV audio tracks and subtitles.

## V1 target

- macOS 15+
- Apple Silicon (arm64)
- No re-encoding for container/track operations
- No Homebrew, Python or system-wide tool installation required for release builds
- Local files remain in place unless the user explicitly chooses another output/safety mode
- No Mac App Store distribution

## Implemented foundation

- Native SwiftUI application shell
- Files view with MKV drag & drop
- File importer accepting MKV files and folders
- Recursive MKV discovery inside imported folders
- Per-file analysis status and errors
- Analysis cache keyed by file size and modification date
- FFprobe JSON analysis adapter
- Detailed file inspector with container, duration, size and track metadata
- Video/audio/subtitle track summaries
- Default, Forced and SDH/HI indicators
- Explainable processing operation and plan models
- Bounded batch scheduler foundation with Auto / Manual 1–20 / Economy concurrency modes
- MKVToolNix `mkvpropedit` command service for track metadata changes
- Cancellation-aware process runner
- Tool lookup inside the application bundle

## Planned V1 modules

1. MKVToolNix identification and track-UID mapping
2. Safe track editing: language, title, Default, Forced, SDH/HI, add/remove/replace/reorder
3. Extraction and subtitle format conversion
4. Synchronization engines and confidence reporting
5. Full batch execution with resource-aware scheduling
6. Presets/rules with simulation and explainable decisions
7. Before/after subtitle preview using mpv/libmpv
8. Season-wide comparison view
9. History, validation and rollback/backup handling
10. Release packaging with bundled arm64 dependencies

## Bundled tools

Release packaging will embed the required command-line tools inside the application bundle. The current target versions are MKVToolNix 101.0 and FFmpeg 9.0.1; versions are pinned by the release workflow so builds remain reproducible.

Third-party licenses and notices will be shipped with the application and exposed from the About section.

## Development

The application is built with Swift 6 and SwiftUI using a native Xcode project. CI validates the arm64 macOS target.

The application is intentionally usable without third-party binaries during development: analysis and processing features report a clear missing-engine error until the bundled tools are present.

## Distribution

V1 is intended to be distributed through GitHub releases. It is not notarized in the initial release because an Apple Developer Program membership is not available. macOS may therefore display its unidentified-developer warning on first launch.
