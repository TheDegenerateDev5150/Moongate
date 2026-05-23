# Moongate — Claude Code Project Guide

## What this project is

Moongate is a free, open-source Android app for remotely controlling a Klipper 3D printer over local WiFi or Cloudflare Quick Tunnel. No VPN, no Tailscale, no subscriptions.

Two parts:
- **Moongate App** — Flutter/Android app (dashboard webcam tiles, print controls, full Mainsail WebView)
- **Moongate Plugin** — Python Moonraker component on the Pi (pairing, JWT auth, status/control proxy, Cloudflare tunnel)

## Repository layout

```
moongate/
├── mobile/                  # Flutter app (Dart)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── app.dart
│   │   ├── features/
│   │   │   ├── auth/        # Pairing flow, QR scanner (pairing_screen.dart)
│   │   │   ├── dashboard/   # Dashboard + PrinterTile widget
│   │   │   ├── printer/     # Printer screen (Mainsail WebView)
│   │   │   └── settings/    # App settings
│   │   ├── services/
│   │   │   ├── printer_status_service.dart   # Per-tile status polling
│   │   │   ├── print_control_service.dart    # pause/resume/cancel/firmware_restart
│   │   │   ├── printer_registry.dart         # Persistent printer list
│   │   │   └── moonraker_service.dart        # WebSocket client
│   │   └── models/
│   │       └── printer_config.dart           # PrinterConfig, PrinterStatus
│   └── android/
│       └── app/src/main/kotlin/.../MainActivity.kt   # FlutterFragmentActivity (required for CameraX)
├── klipper-plugin/
│   ├── moongate_standalone.py   # Single-file Moonraker plugin
│   ├── moongate-pair.html       # QR pairing page
│   ├── install.sh               # One-line Pi installer
│   └── uninstall.sh             # Complete remover
├── APK/                         # Pre-built release APKs + latest_version.json
└── .github/workflows/
    └── build-android.yml        # Builds + signs + commits APK on push to master
```

## GitHub

Repo: https://github.com/PEEKYPAUL/Moongate  (capital M)
Branch: `master` (not `main`)
Push all changes to `master`. CI auto-builds the APK and commits it back.

## Current open issue — Camera QR scanner always fails

**Status as of v0.2.7:** The QR scanner on the pairing screen shows "Camera unavailable" with `genericError` on every attempt. We have not yet identified the root cause. The `errorBuilder` in `pairing_screen.dart` was fixed in v0.2.7 to show the actual native error fields — the next step is to reproduce the error with the phone connected and read the logcat to see the real CameraX exception.

What has already been tried:
- `FlutterFragmentActivity` (v0.2.4) — CameraX requires this for LifecycleOwner
- `MobileScannerController(autoStart: false)` + deferred `start()` in `addPostFrameCallback` (v0.2.6)
- 700 ms delay on first-ever permission grant (v0.2.6)
- Fixed `errorBuilder` diagnostic to expand `MobileScannerErrorDetails` fields (v0.2.7)

**How to reproduce and capture the error (do this when phone is connected):**

```bash
# Terminal 1 — clear logcat then stream filtered camera events
adb logcat -c
adb logcat | grep -iE "(MobileScanner|CameraX|camera|bindToLifecycle|lifecycle)"

# Terminal 2 — run app in debug mode on the phone
cd mobile
flutter run
```

In the app: Add Printer → tap the QR code icon → camera fails → read Terminal 1 output.

The `message` field in the logcat output is the actual Android/CameraX exception text. That is what tells us exactly what is wrong.

## Development prerequisites (home PC setup)

1. **Flutter SDK** ≥ 3.19 stable — https://docs.flutter.dev/get-started/install
   - After install: `flutter channel stable && flutter upgrade`
2. **Android Studio** (Hedgehog or later) — includes Android SDK, ADB, emulator
   - Install Flutter + Dart plugins inside Android Studio
3. **JDK 17** — Android Studio usually bundles this; verify with `java -version`
4. **Git** — `git --version`
5. **Claude Code CLI** — `npm install -g @anthropic/claude-code` (requires Node 18+)

### One-time project setup on a new machine

```bash
git clone https://github.com/PEEKYPAUL/Moongate.git
cd Moongate/mobile
flutter pub get
flutter doctor          # fix any issues it reports
```

### Connecting the Android phone for debugging

1. On the phone: Settings → About → tap **Build Number** 7 times → Developer Options appear
2. Enable **USB Debugging** in Developer Options
3. Plug in via USB cable
4. Phone shows "Allow USB debugging?" — tap **Allow** (check "Always allow from this computer")
5. Verify: `adb devices` should list your device (not just "unauthorized")

### Release signing (only needed for release APK builds)

For debug testing (`flutter run`) no signing setup is needed.
For release builds locally: copy `moongate-release.jks` and `key.properties` from the work machine to `mobile/android/` (both are gitignored). The CI uses GitHub Secrets for this.

## Key architecture decisions

- **Network strategy**: Local IP first (fast at home), auto-fallback to Cloudflare Quick Tunnel. Each tile probes its own IPs independently.
- **Status polling**: `PrinterStatusService` polls every 4 s. Tries Moongate plugin endpoint first; falls back to native Moonraker API.
- **Print controls**: Same dual-endpoint strategy — Moongate first, then native Moonraker.
- **Tunnel URL rotation**: `cloudflared` generates a new URL on each Pi restart. Plugin injects the current URL into every status response; app detects changes and persists the fresh URL automatically.
- **Pairing**: `MOONGATE_PAIR` macro → `GATE-XXXX-XXXX` code + QR → app scans → JWT token stored.
- **Connection indicator**: Green / "Local" = home WiFi. Orange / "Tunnel" = Cloudflare tunnel.

## Coding conventions

- Dart: `flutter_lints` rules, feature-first folder structure, `withValues(alpha:)` not `withOpacity()`
- Python: PEP 8, type hints on public functions, no external runtime deps beyond Moonraker
- Commit often and push; CI runs on every push to `master`

## Autonomy — when to ask vs just do it

**Never ask for confirmation on:**
- Editing or creating any source file (Dart, Python, YAML, JSON, shell, HTML, Kotlin)
- Running `flutter pub get`, `flutter analyze`, `flutter build`, `adb` commands
- Git commits and `git push`
- Any reversible code or config change

**Do ask before:**
- Deleting files permanently
- Force-pushing to a branch that already has history
- `git reset --hard` discarding local work
- Any irreversible destructive action

Default mode: **make the change, then tell the user what was done.**
