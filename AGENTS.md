# Security Cameras Project Notes

## Overview
- Native SwiftUI app for macOS/iOS targeting 26+.
- Uses periodic JPEG snapshots for "near-live" camera viewing.
- Camera configs are persisted via `@AppStorage` as JSON.

## UI Structure
- Root uses `NavigationSplitView`.
- Sidebar lists cameras and shows availability via a green checkmark.
- Detail view shows the selected camera snapshot in a full-size panel.
- Settings sheet lets users add/remove cameras.

## Streaming Approach
- Snapshot polling every 5 seconds using the Reolink Snap endpoint.
- Snapshot URL format:
  - `http(s)://<host>/cgi-bin/api.cgi?cmd=Snap&channel=<n>&user=<user>&password=<pass>`
- `SnapshotView` performs the fetch and updates the image.
- `AvailabilityProbe` checks reachability every 5 seconds and updates sidebar state.

## Files of Interest
- `Security Cameras/ContentView.swift`: UI, persistence, polling logic.
- `Security Cameras/Info.plist`: ATS overrides + local network usage description.
- `Security Cameras.xcodeproj/project.pbxproj`: uses manual Info.plist.

## Notes
- ATS is relaxed for local network HTTP access; tighten if needed.
- App Sandbox is currently disabled due to a sandbox crash (re-enable once entitlements are sorted).
