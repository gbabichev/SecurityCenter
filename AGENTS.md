# Security Center Agent Notes

## Project Shape
- Workspace root is `SecurityCenter`, and the Xcode project, target, and app folder are `Security Center`.
- Native SwiftUI app for macOS + iOS.
- Main app entry: `Security Center/SecurityCenterApp.swift`.
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
- Import/export uses the same JSON payload shape as the in-app persisted model.

## Important Runtime Behavior
- Reolink JPG:
  - uses `/cgi-bin/api.cgi?cmd=Snap...`
  - substream currently uses width/height fallback query parameters
- RTSP:
  - rendered by `VLCKitSPM` in `RTSPStreamView.swift`
  - reconnect logic lives inside the VLC coordinator
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
  - macOS uses `SettingsSection` / `SettingsRow`
  - iOS uses larger touch-friendly controls and separate editor sheets
- Main settings and camera editor both use top-right `Done`.
- App settings stay local until `Done`.
- Camera edits stay local until `Save`.
- On iOS and macOS, camera editing happens in a separate overlay sheet.

## Files That Matter Most
- `Security Center/Logic/AppViewModel.swift`
  - source of truth for persistence, validation, grids, quiet hours, selection
- `Security Center/Models/Models.swift`
  - enums, camera model, grid model, quiet hours model
- `Security Center/UI/ContentView.swift`
  - split view, sidebar, settings presentation, new grid flow
- `Security Center/UI/CameraSettingsView.swift`
  - app settings UI + camera editor UI
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

## Grid Notes
- Hardcoded grid presets were removed.
- Default grid is `2x2`.
- Users create saved grids from the sidebar `+`.
- Filled macOS grid cells use double-click to reassign camera.
- Empty cells use a centered `Select Camera` menu.

## Platform Notes
- `SettingsSection.swift` is macOS-only.
- `IdleCursorHider.swift` matters mainly on macOS.
- iOS settings include native import/export pickers.
- iOS sidebar title should be attached to the sidebar column, not the outer split view.

## Build / Verify
- Preferred verification is generic destination `xcodebuild`, unsigned.
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
