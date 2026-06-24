# Moongate iOS port, working plan

Status: STARTING (2026-06-24). Hardware in hand: MacBook Air and iPhone 14 Pro. This plan turns the iOS port from a logged idea into a sequenced piece of work, grounded in an audit of the current code rather than assumptions.

## Where we stand

A full readiness audit of the current app found it in strong iOS shape, not a from-scratch port:

- The iOS scaffold is complete and modern: Xcode project, iOS 13 target, scene manifest, icon slots.
- Almost every plugin already supports iOS (webview, biometrics, scanner, file picker, secure storage, mDNS via bonsoir, supabase, and more).
- Platform-specific work is partly done already: the bug-report device info already branches for iOS, the in-app update path already falls back to a browser on iOS, and both native Android channels (the screenshot block and the APK installer) no-op safely on iOS.

The genuine gaps are short and known:

1. Info.plist is missing the privacy strings iOS requires (camera, Face ID, local network, Bonjour) and an ATS exception for the plain HTTP LAN path. Without these, QR scanning, biometrics, and all LAN access silently fail.
2. The PayPal donation prompt is not guarded for iOS, which is a near-certain App Store rejection.
3. App icons are still Flutter defaults (flutter_launcher_icons is off for iOS).
4. Print notifications run on an Android foreground service, which iOS has no equivalent for. They no-op safely, so nothing crashes, but iOS gets no background print alerts without new work.

## Why this is tractable, and where the real work actually is

It is fair to expect iOS to be smoother than Android in one important way: far less device and OS fragmentation. A handful of screen sizes, a controlled OS, no vendor skins, so the testing surface is small and predictable, and the app is already proven on Android. That part genuinely carries over.

The friction on iOS is not hardware variety, it is Apple's platform rules: the App Store review gate, code signing and provisioning, the privacy declarations, and the one real API gap (no foreground service, so notifications need a different mechanism). None of those are reduced by uniform hardware. So the realistic read is that the code port is modest, and the attention goes into the App Store process and the notifications decision.

## Sequencing principle

The port work (Phases 0 to 2) is the same no matter what we decide about notifications. So we do it first and get the app onto TestFlight on the real iPhone. That validates the port cheaply and early, and it lets the one contentious decision (when iOS goes public, and whether it waits for notifications) be made later with the app actually running, rather than guessed now.

## Phase 0, Mac and Apple account setup
- [ ] Xcode and command line tools, CocoaPods, Flutter on the MacBook Air.
- [ ] Enrol in the Apple Developer Program ($99/yr). Required for on-device testing beyond 7 days, TestFlight, and the App Store.
- [ ] Clone the repo, `flutter pub get`, `pod install`. Start with Xcode automatic signing.

## Phase 1, first build and run on the iPhone 14 Pro
- [ ] `flutter run` on the device, clear any pod or signing issues.
- [ ] Exercise the whole app on real hardware: QR pairing, dashboard, the Mainsail webview, LAN vs tunnel, biometric app lock, backup and restore.
- [ ] Note what the missing Info.plist strings break first (expected: camera and local network), which confirms the Phase 2 list.

## Phase 2, iOS config fixes (the real code work, roughly 2 to 3 days)
- [ ] Info.plist: NSCameraUsageDescription, NSFaceIDUsageDescription, NSLocalNetworkUsageDescription, NSBonjourServices (`_moongate._tcp`), and an ATS exception (NSAllowsLocalNetworking) for the HTTP LAN path.
- [ ] Guard the PayPal donation prompt with `Platform.isAndroid` so it does not show on iOS.
- [ ] Enable flutter_launcher_icons for iOS and regenerate icons from the real artwork.
- [ ] On iOS, hide or relabel the print-notification settings so users are not offered a feature that does nothing yet.
- [ ] Confirm the bundle ID decision is locked (see Decisions).

## Phase 3, notifications (decided per Decisions below)
- If we build the push backend: FCM for Android, APNs for iOS, a cloud sender triggered by printer heartbeat or state change, and an app-side receiver. Tracked in the push-notifications plan, and it also fixes the Android #126 idle-notification problem and may ease Edge Function cost.

## Phase 4, App Store submission
- [ ] Privacy policy URL (required) and the App Privacy disclosures (anonymous sign-in, diagnostics).
- [ ] Screenshots and metadata, plus a reviewer note justifying the local-network exception.
- [ ] TestFlight on the iPhone first, then submit for review.

## Phase 5, dual-store and CI
- [ ] Add an iOS build workflow (a macOS runner or Codemagic) so iOS builds sign and ship like the Android one.
- [ ] Settle the simultaneous Google Play and App Store update flow for the launch.

## Decisions

### 1. Notifications and iOS release timing
**Recommendation:** build the port now and get it to TestFlight regardless. Lean towards holding the public App Store release until the push backend is built, so iOS launches with notifications working and Android gets the #126 fix at the same time. That is a parity launch, which matches the simultaneous-launch goal. If the backend turns into a long pole, fall back to releasing iOS without notifications and adding them in a later update for both platforms. The key point: the port does not wait on this, and the call is made once the app is proven on TestFlight.

### 2. iPad
**Recommendation:** iPhone-first for v1. The only Apple test hardware on hand is the iPhone 14 Pro, and shipping an iPad layout we cannot test on a real device is a needless risk. The grid UI would likely suit a tablet, so iPad is a strong fast-follow once there is an iPad to test on. The public note ("iPhone and iPad on the way") still holds, iPad just lands a little later.

### 3. Bundle identifier
**Recommendation:** keep `com.moongate.app.moongate`. The doubled word is slightly ugly but harmless, and it already matches the Android applicationId, which is permanently fixed on Google Play. Changing iOS to `com.moongate.app` would buy marginal tidiness at the cost of diverging from Android and disturbing the working signing setup. It is permanent once submitted, so this is locked here deliberately.

## Milestones
- Running on the iPhone 14 Pro: a day or two of setup (Phases 0 to 1).
- TestFlight-ready and App Store-submittable without notifications: roughly a week of focused work (Phases 0, 1, 2, 4).
- Notifications working via the push backend, both platforms: a separate effort of a few weeks (Phase 3).

## Open risks
- App Store review on the local-network exception and the anonymous-auth privacy disclosure. Mitigated by clear reviewer notes.
- The donation guard must land before the first submit, or it is an instant rejection.
- The push backend is the largest single piece. It benefits both platforms, so it is worth scoping carefully on its own before committing to it.
