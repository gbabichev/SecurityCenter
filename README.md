<div align="center">

<picture>
  <source srcset="docs/icon-dark.png" media="(prefers-color-scheme: dark)">
  <source srcset="docs/icon-light.png" media="(prefers-color-scheme: light)">
  <img src="docs/icon-light.png" alt="Security Center icon" width="108">
</picture>

## Security Center

Native camera monitoring for macOS and iOS.

[Website](docs/index.html) ·
[Support](docs/Support.html) ·
[Privacy](docs/PrivacyPolicy.html)

</div>

<p align="center">
  <a href="docs/mac1.jpg"><img src="docs/mac1.jpg" height="260" alt="Security Center saved grid on macOS"></a>
  <a href="docs/iPad1.jpg"><img src="docs/iPad1.jpg" height="260" alt="Security Center running on iPad"></a>
</p>

Security Center brings Reolink snapshot feeds and RTSP streams into one native app, with saved grids, quiet hours, local import and export, and settings that stay understandable.

Built for people who want a direct, local way to monitor cameras without turning setup and day-to-day use into a maintenance project.

## Features

- Reolink JPG and RTSP in one app, plus generic RTSP support
- Saved grids with camera assignment and sidebar switching
- Sidebar availability checks for enabled cameras
- Quiet hours that black out the screen and pause polling, streaming, and probing
- Per-camera editing for names, source settings, stream selection, mute, copy, disable, and validation
- Local JSON import and export for moving configuration between installs
- Theme and view background settings
- Native macOS Settings window with General, Quiet Hours, Cameras, Grids, and Configuration tabs (⌘,); preferences save immediately
- Shared SwiftUI app for macOS and iOS with platform-specific settings flows
- Local-first setup: camera traffic goes directly to the endpoints you configure


## Camera Modes

| Type | Feed Options |
| --- | --- |
| Reolink Camera | `Reolink JPG`, `RTSP` |
| Generic RTSP Stream | `RTSP` |

## Platforms

- macOS 15.0 or later
- iOS 18.0 or later
- Built with SwiftUI and `VLCKitSPM`

## What It Stores

Security Center stores its app state locally in `UserDefaults`, including:

- Cameras
- Saved grids
- Grid assignments
- Grid picture style
- Theme and view background
- Selected sidebar item
- Quiet hours

## Privacy

Privacy details live in [docs/PrivacyPolicy.html](docs/PrivacyPolicy.html).

## Work In Progress

I am continuing to work on improving performance of the iOS branch. Once I am happy with the results, it will be submitted to the App Store for release.

## Changelog

### 1.0.1
- Added "Keep Screen Awake" setting. Screen is kept awake by default when streaming, but would go to sleep during Quiet Hours. This setting prevents that.

### 1.0.0
- Initial macOS release. iOS works, but you have to compile yourself.