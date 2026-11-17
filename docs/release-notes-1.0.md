# AppMonitor 1.0

The first public release of AppMonitor, a calmer process monitor for macOS.

**[Download AppMonitor.zip](https://github.com/OfflinePigeon/AppMonitor/releases/download/v1.0.0/AppMonitor.zip)** · **[Repository](https://github.com/OfflinePigeon/AppMonitor)**

## Highlights

- **Quit the selected app.** The red power button in the toolbar now quits the application selected in the list, not AppMonitor itself. It uses the normal graceful-quit path, so unsaved-work prompts still appear.
- **Stable main list.** Applications are ordered once by CPU at launch and then stay frozen while metrics update in place. New apps append instead of inserting.
- **Live inspector.** The Live Applications card ranks every running app by current CPU and updates every 2.5 seconds. Click any row to select it in the main list.
- **Manual re-ranking.** Choosing CPU, Memory, or Name re-orders the list once, then freezes it again.
- **Application-first grouping.** Chrome renderers, Xcode workers, WebKit content processes, and Electron helpers nest under their parent app.
- **Honest filtering.** High CPU, High Memory, and Favorites filters, with a visible count of filtered background tasks.
- **Native and local.** SwiftUI, public libproc APIs, no root access, no account, and no telemetry.
- **New app icon.** A clean power symbol on a navy-to-teal tile, generated reproducibly with AppKit.

## Install

1. Download `AppMonitor.zip`.
2. Unzip it and move `AppMonitor.app` into `/Applications`.
3. Open the app. The build is ad-hoc signed; if Gatekeeper warns on first launch, right-click the app and choose **Open** once.

## Requirements

- macOS 14 Sonoma or later
- Universal binary for Apple silicon and Intel

## Integrity

```text
SHA-256  1cb081d6f67dd701ff2aaa9ea8b3a0d16445e1c4bb2bd9198c19c5f51a392a12
Size     2.5 MB
```
