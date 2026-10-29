# Security Center Agent Notes

## Project Shape
- Workspace root is `SecurityCenter`, and the Xcode project, target, and app folder are `Security Center`.
- Native SwiftUI app for macOS + iOS.
- Main app entry: `Security Center/SecurityCenterApp.swift`.
- Repo root also contains project docs:
  - `README.md`
  - `docs/` static support/privacy/marketing site
- Root UI uses `NavigationSplitView` with:
  - sidebar camera list
  - sidebar saved grids
  - detail area for single camera or grid

## What The App Does
- Supports 2 camera kinds:
  - `Reolink Camera`
  - `Generic RTSP Stream`
- Supports 2 feed modes:
  - `Reolink JPG` for still-image refresh
  - `RTSP` for live video
- Users can:
  - add/edit/delete/copy cameras
  - disable cameras
  - choose main stream vs substream
  - mute RTSP cameras
  - assign cameras into saved custom grids
  - set quiet hours that black out the screen and pause camera traffic

## Current Persistence Model
- State is stored in `UserDefaults` by `AppViewModel`, not `@AppStorage`.
- Persisted items:
  - cameras JSON
  - grids JSON
  - grid assignments JSON
  - grid picture style
  - selected sidebar item
  - quiet hours JSON
- Default grid is a real persisted `2x2` grid with a stable UUID, not an ephemeral generated grid.
- `AppViewModel` contains migration logic for older installs that used the implicit default grid, so saved assignments and last-selected grid survive upgrade.
- Import/export uses the same JSON payload shape as the in-app persisted model.

## Important Runtime Behavior
- Reolink JPG:
  - uses `/cgi-bin/api.cgi?cmd=Snap...`
  - substream currently uses width/height fallback query parameters
  - validation probes the opposite HTTP/HTTPS setting and can surface explicit `Try HTTP instead.` / `Try HTTPS instead.` errors
- RTSP:
  - rendered by `VLCKitSPM` in `RTSPStreamView.swift`
  - reconnect logic lives inside the VLC coordinator
  - `RTSPFrameWatchdog` checks displayed-frame progress every 2 seconds, allowing 30 seconds for initial video and 20 seconds without progress afterward. It runs independently of logging, suspends checks for non-rendering viewers, and resets grace after long sampling gaps. Stall recovery forces a media reopen using existing reconnect backoff.
  - uses a shared `VLCLibrary`, not a separate libVLC instance per tile
  - muted RTSP cameras use VLC's `no-audio` media option to skip audio processing. Changing mute recreates the player to apply audio selection; unmuting restores normal audio.
  - audio-processing experiment keeps TCP transport, 1000 ms caching, and video decoder selection unchanged; compare debug logs against the saved baseline.
  - currently prefers stability over minimum latency:
    - `--rtsp-tcp`
    - `network-caching=1000`
    - `live-caching=1000`
- Availability:
  - sidebar status is driven by `AvailabilityProbe`
  - probing pauses during quiet hours
- Quiet Hours:
  - app-wide
  - black screen + moving saver card
  - stops polling / streaming / availability checks

## Current UX Rules
- Avoid technical wording in user-facing copy where possible.
- macOS settings and iOS settings intentionally diverge:
  - macOS uses a native `Settings` scene with General, Quiet Hours, Cameras, Grids, and Configuration tabs
  - iOS uses larger touch-friendly controls and separate editor sheets
- macOS preferences save immediately; close the native Settings window when finished.
- iOS app settings stay local until the top-right `Done`.
- macOS camera editors use compact Connection / Picture & Sound / Display pages, a top-right Done button, and a fixed action footer. After saving, the footer also shows Done.
- macOS Connection contains camera kind, JPG/RTSP feed choice, address/login, and HTTP/HTTPS (JPG only). Picture & Sound contains stream quality, refresh timing, and mute.
- Connection > Check Connection tests current draft details without saving, including disabled cameras. JPG checks use the selected protocol without probing the opposite one; save validation retains alternate-protocol suggestions. Saving still validates enabled cameras; standalone connection checks do not check for duplicate saved cameras.
- iOS camera editors use top-right `Done` to close and `Save` to commit.
- Camera edits stay local until `Save`.
- On iOS and macOS, camera editing happens in a separate sheet; on macOS it belongs to the Settings window.
- On macOS, the gear button and native app-menu Settings… (⌘,) open the same Settings window. There is no separate File > Configuration command.
- Sidebar context menus are part of the main workflow now:
  - cameras: `Edit`, `Delete`
  - grids: `Edit Grid`, `Delete`

## Files That Matter Most
- `Security Center/Logic/AppViewModel.swift`
  - source of truth for persistence, validation, grids, quiet hours, selection
- `Security Center/Models/Models.swift`
  - enums, camera model, grid model, quiet hours model
- `Security Center/UI/ContentView.swift`
  - split view, sidebar, settings presentation, new grid flow
- `Security Center/UI/CameraSettingsView.swift`
  - iOS app settings UI + shared camera editor + macOS camera pane
- `Security Center/UI/MacSettingsView.swift`
  - native macOS Settings tabs, immediate preferences, and camera editor routing
- `Security Center/UI/MacCameraEditor.swift`
  - compact macOS camera editor pages and validation feedback
- `Security Center/UI/GridSettingsPane.swift`
  - macOS grid management and draft-based grid editor
- `Security Center/UI/ConfigurationTransferView.swift`
  - Configuration tab with selective import and full export
- `Security Center/UI/CameraDetailView.swift`
  - single-camera detail
- `Security Center/UI/GridDetailView.swift`
  - grid rendering and camera assignment
- `Security Center/UI/SnapshotView.swift`
  - JPG fetching / display
- `Security Center/UI/RTSPStreamView.swift`
  - RTSP playback wrapper
- `Security Center/UI/AvailabilityProbe.swift`
  - camera reachability checks
- `Security Center/UI/QuietHoursSaverView.swift`
  - blackout screen UI during quiet hours

## Settings / Editor Notes
- Camera copy should duplicate 1:1 and rename to `"<name> Copy"`.
- Delete confirmation had a double-prompt bug before; current fix defers delete until after dialog state clears.
- `Camera enabled` is intentionally near the top of the camera editor.
- `Copy URL` / camera link actions are user-facing utilities; keep the wording plain.
- In the camera list inside settings, RTSP cameras show an audio-state icon in the subtitle row:
  - `speaker.wave.2.fill` when not muted
  - `speaker.slash.fill` when muted

- macOS View > Turn On/Off Quiet Hours uses ⌘⇧M and works even when the toolbar moon button is hidden.

## Camera Background Blur
- Appearance includes an optional Blur camera background setting (off by default), persisted by AppViewModel and included in JSON display settings.
- CameraBackdrop matches the gallery treatment: 80-point overscan, 30-point blur, and 35% black overlay.
- JPG reuses the downloaded image. RTSP captures 256-pixel frames from its existing VLC player once when video is ready and then every 30 minutes, with no second connection.
- RTSP captures use a temporary directory that is removed when capture stops; snapshot previews and VLC on-screen messages are disabled to prevent filename popups.
- Capture readiness uses actual VLC video output, not state == playing: VLC can remain buffering while rendering. Publish captured frames from mediaPlayerSnapshot completion callbacks.
- Single-camera views and grids using Keep camera shape can show the backdrop. Match box shape skips captures because no gaps remain.
- Quiet hours remove the camera views and stop capture; disabled cameras do not show a backdrop.

## Grid Notes
- Hardcoded grid presets were removed.
- Default grid is `2x2`.
- macOS Settings includes a Grids tab for creation, editing, camera assignments, and deletion. Changes apply on Create/Save.
- Configuration > Reset Grids requires confirmation, restores one empty default `2x2` grid, and keeps cameras/preferences.
- Grid deletion keeps at least one grid; use Reset Grids to clear the final layout.
- Sidebar Cameras and Grids headers both have an add `+` button. Sidebar camera add/edit presents the shared camera editor directly, without opening Settings. Settings presents the same editor and save/validation logic.
- Sidebar and Settings grid creation/editing reuse `GridSettingsEditor`, including camera assignments; sidebar saves select the saved grid.
- Editing a grid reuses the same sheet as new-grid creation, but pre-populates the existing name/rows/columns.
- Resizing an existing grid preserves assignments where possible, truncates overflow when shrinking, and pads with empty slots when growing.
- Filled macOS grid cells use double-click to reassign camera.
- Empty cells use a centered `Select Camera` menu.
- Grid picture style has 2 modes:
  - `Keep camera shape`
    - preserve the original aspect ratio
    - gaps are allowed
  - `Match box shape`
    - stretch non-uniformly to remove gaps
    - still shows the full frame; it does not crop

## Platform Notes
- `IdleCursorHider.swift` matters mainly on macOS.
- iOS settings include native import/export pickers.
- iOS sidebar title should be attached to the sidebar column, not the outer split view.
- macOS local-network usage text is declared in the generated Info.plist build settings, not in a checked-in plist file.

## Build / Verify
- Preferred verification is generic destination `xcodebuild`, unsigned.
- `.periphery.yml` configures unused-code scans and retains synthesized equality fields needed by SwiftUI task identities and reconnect tickets. Use a clean scan after deleting declarations to avoid stale index findings.
- Common commands:
  - macOS:
    - `env HOME=$PWD/.home CLANG_MODULE_CACHE_PATH=$PWD/.cache/clang/ModuleCache SWIFTPM_MODULECACHE_OVERRIDE=$PWD/.cache/org.swift.swiftpm CFFIXED_USER_HOME=$PWD/.home xcodebuild -project 'Security Center.xcodeproj' -scheme 'Security Center' -destination 'generic/platform=macOS' -clonedSourcePackagesDirPath '.sourcepackages' -derivedDataPath '.derivedData' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build`
  - iOS:
    - `env HOME=$PWD/.home CLANG_MODULE_CACHE_PATH=$PWD/.cache/clang/ModuleCache SWIFTPM_MODULECACHE_OVERRIDE=$PWD/.cache/org.swift.swiftpm CFFIXED_USER_HOME=$PWD/.home xcodebuild -project 'Security Center.xcodeproj' -scheme 'Security Center' -destination 'generic/platform=iOS' -clonedSourcePackagesDirPath '.sourcepackages' -derivedDataPath '.derivedData-ios' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build`
- Expected non-blocking warning:
  - `Metadata extraction skipped. No AppIntents.framework dependency found.`

## Known Repo Quirks
- Local build scratch dirs may exist in repo root:
  - `.cache`
  - `.home`
  - `.sourcepackages`
  - `.derivedData`
  - `.derivedData-ios`
- These are local artifacts, not source.

## Editing Guidance For Future Agents
- Do not assume older notes are accurate; the app evolved from snapshot-only into mixed JPG/RTSP.
- Check both macOS and iOS settings flows before refactoring shared UI.
- When changing user copy, keep it plain and non-technical unless the app truly needs precision.
- When changing persistence, inspect `AppViewModel` first; most behavior fans out from there.

## Streaming Diagnostics
- Enable Debug Logging is a device-local UserDefaults setting in AppViewModel, off by default and excluded from configuration exports.
- macOS: Settings > General > Diagnostics includes Show Logs in Finder. iOS uses the existing draft/Done flow and Share Debug Log.
- StreamDebugLog writes on a bounded serial utility queue to Application Support/Security Center/Logs. File rotation retains stream-debug.log and three 5 MB archives across restarts.
- Redact full camera URLs, authentication headers, and registered raw/encoded credentials before disk writes. Never bypass this writer with a native VLC file logger.
- VLCStreamLogger captures native VLC messages through the shared library. Each coordinator logs camera/session identity, playback states, reconnects, snapshot activity, and 5-second decoder/displayed/lost-frame statistics plus audioProcessing/audioDecoded/audioPlayed fields.
- Diagnostics must not change playback or reconnect behavior. Logging is observational; the frame watchdog is a separate recovery mechanism. Reconnect attempts use a one-use `RTSPReconnectGate` ticket checked on the playback actor immediately before media replacement; recovery, source changes, shutdown, and newer retries invalidate old tickets.
- Tests/StreamDebugLogTests.swift verifies disabled logging, redaction, concurrent writes, restart retention, and rotation. README includes the standalone test command.

- `Tests/RTSPReconnectGateTests.swift` covers cancellation after preflight, recovered playback, superseded retries, source changes, shutdown, and valid one-use retries.
