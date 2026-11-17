# AppMonitor 1.0

The first public release of AppMonitor, a calmer process monitor for macOS.

**[Download AppMonitor.zip](https://appmonitor.surge.sh/AppMonitor.zip)** · **[Website](https://appmonitor.surge.sh)**

## Highlights

- **Stable main list.** Applications are ordered once by CPU at launch and then stay frozen while metrics update in place. New apps append instead of inserting.
- **Live inspector.** The Live Applications card ranks every running app by current CPU and updates every 2.5 seconds. Click any row to select it in the main list.
- **Manual re-ranking.** Choosing CPU, Memory, or Name re-orders the list once, then freezes it again.
- **Application-first grouping.** Chrome renderers, Xcode workers, WebKit content processes, and Electron helpers nest under their parent app.
- **Honest filtering.** High CPU, High Memory, and Favorites filters, with a visible count of filtered background tasks.
- **Native and local.** SwiftUI, public libproc APIs, no root access, no account, and no telemetry.
- **New app icon.** A dark teal monitor-and-pulse mark, generated reproducibly with AppKit.

## Install

1. Download `AppMonitor.zip`.
2. Unzip it and move `AppMonitor.app` into `/Applications`.
3. Open the app. The build is ad-hoc signed; if Gatekeeper warns on first launch, right-click the app and choose **Open** once.

## Requirements

- macOS 14 Sonoma or later
- Universal binary for Apple silicon and Intel

## Integrity

```text
SHA-256  7cb1c97bfc12d5a5a3ebaabfc4f3bbe8bb3369e9d2cea2f534a73bf0a256242d
Size     2.5 MB
```
