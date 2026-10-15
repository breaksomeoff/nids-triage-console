# NIDS Triage Console

A mobile and web console for triaging alerts raised by a flow-based
Network Intrusion Detection System (NIDS). It is aimed at the on-call SOC
analyst: see what is open, how severe it is, and decide what to do next
(acknowledge, escalate, close) from a phone or a browser.

Built with [Flutter](https://flutter.dev) from a single codebase for
Android, iOS and the web.

> Developed for the *Enterprise Mobile Application Development* course
> at the University of Salerno (2026/27).
>
> **Team:** Alessio Inglese, Giuseppe Di Somma

**Live web build:** https://breaksomeoff.github.io/nids-triage-console/

## Status

Early stage. The home screen shows the analyst on duty, the open alerts
grouped by severity and the latest alerts. Alerts are **synthetic mock
data** (`lib/src/data/mock_alerts.dart`): external addresses come from the
RFC 5737 documentation ranges and no real traffic is included.

## Project structure

```
lib/
  main.dart                    app entry point and theme
  src/models/alert.dart        alert, severity and triage status
  src/data/mock_alerts.dart    synthetic alerts
  src/screens/                 UI screens
test/                          widget tests
.github/workflows/pages.yml    CI: analyze, test, deploy web build to GitHub Pages
```

## Getting started

Requirements: Flutter SDK (stable, tested with 3.47.7) and, for Android,
the Android SDK with an emulator or a device.

```sh
flutter pub get
flutter run                 # pick a connected device or emulator
flutter run -d chrome       # web
flutter test
```

Building for iOS requires macOS and Xcode.

## License

Released under the [MIT License](LICENSE).
