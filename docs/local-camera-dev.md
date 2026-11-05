# Local Nanit camera — developer notes

Implementation details, build and hardware validation records for Nestling's local
camera mode. The user-facing guide is [local-camera.md](local-camera.md); it is
published verbatim on the website, so keep build status, test notes and internal
details here instead.

The verified hardware is a Nanit Pro, firmware 6.58.615. Other firmware is not yet
certified compatible.

## Guided setup and help UI

The camera screens live in `lib/src/ui/camera_page.dart`, `lib/src/ui/local_camera_page.dart`
and `lib/src/ui/camera/`:

- `camera_setup_wizard.dart` — `CameraSetupWizard`, one task per screen:
  intro → path (*Already on Wi-Fi* / *Set up Wi-Fi*) → [pairing mode → Bluetooth scan →
  Wi-Fi details] → this device's network → find (search or typed address) → name → done.
  It is also opened from a saved camera's *Change Wi-Fi* with `setupWifi: true`.
  `CameraPage` keeps showing the wizard for its last step after the camera is saved
  (`onSaving`). Test hooks: `wifiSetup`, `discover`, `save`.
- `camera_help_content.dart` — `CameraIssue` (every error state), `CameraHelpTopic`
  (title, why, numbered steps, example, fix actions, search keywords) and the FAQ.
  **The user guide repeats this content.** When changing one, update the other.
- `camera_issues.dart` — maps `LocalCameraFault`, `WifiSetupFault`, `LocalNanitHub.add`
  exceptions, `NanitLiveFailure` and account link failures to a `CameraIssue`.
- `camera_help.dart` — `CameraIssueCard` (problem + steps + only the actions the screen
  can perform), the per-step "Something not working?" sheet, and the searchable
  `CameraHelpPage` (topics by section, FAQ, focus on a topic from "More help").
- `camera_live_tips.dart` — first-visit tips card on the live view (dismissal stored under
  `nestling.localCamera.tipsSeen.v1` in the camera's secret store) and the tips sheet.
- `camera_art.dart` — scene illustrations drawn with `CustomPainter` and Material icons
  from the active `ColorScheme`. The camera is a generic drawing, not Nanit artwork.
- `camera_address_dialog.dart` — address entry with a router device-list example and
  validation via `requireNanitLanAddress`.
- `camera_strings_af.dart` — Afrikaans for the new strings, spread into `afrikaans` in
  `localization.dart`. Keys must not repeat existing keys (const map). A test checks every
  help/FAQ string has a translation.

`LocalNanitHub.fault` and `NanitWifiSetup.fault` classify the existing problem messages;
retry, discovery and protocol behaviour are unchanged. New screens use only
`Theme.of(context).colorScheme`/`textTheme` so the app theme applies; the live video
letterbox stays black.

Screenshots in [images/camera](images/camera) come from the preview renderer:

```powershell
flutter test --run-skipped --tags preview test/camera_preview_test.dart
# build/preview/camera-*.png → copy the ones used by the guide into docs/images/camera/
```

Widget tests: `test/camera_setup_wizard_test.dart` (navigation, back, each Bluetooth/Wi-Fi/
address failure, help search, live-view tips and problem card, Afrikaans fit) plus the
updated onboarding tests in `test/local_nanit_test.dart`.

Not verifiable without hardware: the wording of real Bluetooth errors on each Android
version, whether `UniversalBle.requestPermissions` denial surfaces as
`bluetoothUnavailable` on every OEM, and how long a real camera takes to appear on the
network after accepting Wi-Fi.

## Setup flow, network and lifecycle notes

Discovery tries multicast first; if that is filtered, Nestling tries RTSP discovery in each
local /24 (up to four private interfaces). On a larger subnet, the address must be entered
manually. Bluetooth setup sends a WPA2 SSID/password (hidden-network toggle available); no
cloud registration is sent. Nestling verifies the camera's identity before saving it.

Leaving the screen or backgrounding the app closes video and room/sound-control polling.
Opt-in sound and cry monitoring continues independently. Returning starts muted.
Reconnection retries every 8 seconds while viewing, with mDNS rediscovery if the saved
address stops working, followed by the bounded RTSP fallback. A different serial at the
saved address is rejected. Forgetting removes Nestling's saved entry only. Opening help
from live video pauses the stream; returning resumes muted.

LAN access needs TCP 8081 (maintenance) and 554 (media) to the camera; the in-process
player adapter binds only to loopback on a random port. No inbound LAN stream listener or
external Python process is needed. Nestling does not itself block the camera's WAN access.

Account mode (legacy) instead asks the camera to push RTMP to an in-app receiver on port
1935; status 403 means the camera's stream limit is reached. Its camera token is a
cloud-signed JWT valid about 7 days, renewed when online. Motion alerts there use the
camera's raw frame-difference level scaled by `motionSensitivity`, not Nanit cloud events.

The pairing-button and flashing-night-light guidance follows Nanit's
[camera pairing instructions](https://support.nanit.com/en_us/pairing-the-camera-By48GhCFlg).

Earlier build note: the first-time checklist under *Set up Wi-Fi* and the help page were
inspected in the running Windows app without scanning, provisioning or resetting the
camera; the Windows release and Android GitHub debug APK built successfully at that point.

## Implementation

- `LocalNanitHub` stores only name, UID, firmware and last address via `NanitSecretStore`.
  Its transport has no Nanit account API. A saved local camera suppresses the legacy hub's
  automatic account refresh and control connection.
- `NanitOfflineCamera` identifies the camera and starts its V4L2 source only if absent, using
  fixed FastCGI operations. It does not reboot, read/delete credentials, change firmware,
  register a cloud server, change the microphone mixer or stop the global media source.
- `NanitOfflineBridge` translates RTSP headers/SDP to the camera's internal authority. It
  preserves interleaved RTP/RTCP bytes and recalculates SDP lengths. The player requires TCP.
- `NanitWifiSetup` adapts universal_ble to the package's pure `NanitWifiFlow`. Notifications,
  reads and writes use one GATT connection; disconnecting can end pairing mode. Bluetooth
  setup sends request 15 only. The password is not persisted or logged; mutable packet
  buffers are cleared after use. Runtime strings cannot be guaranteed erased from memory.
- The existing Nanit account UI is optional. Local mode exposes no cloud alerts, recordings,
  motion alerts, breathing monitoring or camera sleep. Local sound and possible-cry alerts
  use Nestling's explicit policy described below.
  Those are not silently represented as supported local features.

Local RTSP/maintenance traffic uses the camera's unauthenticated LAN interfaces. Serial
matching prevents an accidental address mix-up; it is not cryptographic device authentication.
Use it on the owner's trusted LAN. The public UI exposes no arbitrary command entry.

## Validation — 5 November 2026

- Dart transport against the real camera: identity and room readings succeeded; FFmpeg
  decoded 146 video frames at 1920×1080 and 1,292 KiB of incoming PCM audio over 15 seconds.
  Audio was decoded to null, never played. No account tokens were read or used.
- Native Windows Flutter player: decoded 1920×1080 texture, muted playback, then clean pause
  and socket disposal. This caught and fixed a socket-set mutation during stream cleanup.
  A second live test exercised Nestling's complete Camera screen, background/resume and
  staying paused while Wi-Fi setup is open. Both passed against the pinned Git package.
- Discovery: post-reset camera had no mDNS advertisement or port 442 service. RTSP fallback
  found it successfully; interleaving nearby addresses prevents VPN/virtual interfaces from
  exhausting the scan budget before the home interface is checked.
- Android GitHub debug APK built successfully. This PC's Java NIO socket initialization
  needed a process-local `JAVA_TOOL_OPTIONS=-Djdk.net.unixdomain.tmpdir=<existing-short-path>`
  pointing at `.dart_tool/java-tmp`; no project-wide Java or firewall setting was changed.
  The normal Windows release application also built successfully against the pinned package.
- Package tests cover fragmented FastCGI responses, success-marker enforcement, RTSP lengths,
  binary packet preservation, bounded readings/addresses and the recorded BLE handshake.
- App tests cover local-first onboarding at phone width, account flow compatibility,
  metadata-only persistence, no cloud requests, identity mismatch and cancelling connection.
  Final suites: 159 app tests and 81 camera-package tests passed; two optional tests in each
  suite were skipped. App/package analysis reported no issues in the changed code.
- The prior Python research proved Wi-Fi provisioning on this camera after the owner's reset,
  followed by offline video/audio with credential files absent. The new Dart BLE protocol
  replays that exchange in tests. **A fresh end-to-end Flutter BLE pairing on hardware remains
  to be tested**, especially Android permissions/radio behaviour. We did not reset or re-pair
  the already working camera during app development.

The earlier research blocked WAN after Wi-Fi association; provisioning with WAN blocked from
the first association and never-registered hardware remain unverified. No speaker, noise or
breathing actions were triggered in app validation.

```powershell
flutter analyze
flutter test
flutter build apk --flavor github --debug
# Explicit hardware test, muted; replace address with the owned camera:
flutter test integration_test/local_camera_live_test.dart -d windows --dart-define=NANIT_TEST_IP=192.168.1.25
```

The camera package is pinned to a Git commit in `pubspec.yaml`. A local sibling checkout may
be used for development through the ignored `pubspec_overrides.yaml`; release validation must
also resolve the pinned dependency without that override.

## Additional hardware checks — 5 November 2026

After the owner enabled further feature testing, the research PoC verified camera
microphone capture/mute/restore, room readings and brief Wind playback with WAN blocked
and credential files absent. Wind was played for three seconds at 5%, then 30%; digital
speaker output was measured, but user confirmation of audibility remains outstanding.
The camera's native journal also exposed fresh motion active/clear events without an
account, and one fresh active event during a final WAN-blocked observation. Controlled
movement correlation is still outstanding. These newly tested
microphone controls, sound playback and native event access are **PoC functionality, not
additional Nestling UI controls in this commit**.

Breathing's executable/library are installed, but the detector is stopped. A token-free
session/control path and a supervised Breathing Wear test remain unvalidated. Ordinary
motion messages for a region called `sting` are not breathing measurements. No PC
microphone/talk-back or breathing alarm was triggered in this round. Test tooling and
numeric evidence are recorded in the research repo's `OFFLINE_ACCESS.md` and `evidence/`.

The owner then clarified that the mic option means both listening and talk-back. A further
WAN-blocked PoC check played camera AAC audio on the PC and sent five seconds of live Razer
Seiren Mini microphone capture to the camera (80,000 mono PCM16 samples at 16 kHz). Camera
playback exited successfully and its speaker monitor measured a nonzero signal. The input
was extremely quiet, so intelligible speech and practical volume still require a coordinated
spoken test. No speech recording was retained; global mixer settings were unchanged and
temporary helpers/firewall rules were removed. This validates the transport path; it does
not yet add a Talk button to Nestling. Evidence: research repo
`evidence/offline-two-way-audio-2026-11-05.json`.

An owner-coordinated follow-up used the selected Razer microphone for five seconds.
Input RMS was −48.49 dBFS, and the camera's digital speaker monitor again measured
the output with WAN blocked and tokens absent. Playback completed and cleanup was
verified; audible speech clarity still awaits the owner's confirmation. Evidence:
research repo `evidence/offline-spoken-audio-2026-11-05.json`.
The requested ten-second repeat also completed, but microphone input was only
−83.71 dBFS, so it did not resolve speech clarity. The corresponding `offline-spoken-audio-repeat-2026-11-05.json`
records delivery, isolation and cleanup; user confirmation of speaking/audibility
is still pending.

## Stream stability and latency — 5 November 2026

The Windows delay/disconnection report exposed three independent problems:

- The RTSP bridge applied the same 20-second receive timeout in both directions.
  An RTSP player can send no control requests during that interval while the camera
  continues sending RTP. The bridge now allows that client silence, while retaining
  a timeout for camera inactivity and stalled writes. TCP_NODELAY is enabled on both
  sides. A fake-camera regression test reproduced the early disconnect before the fix.
- A delayed or failed temperature/humidity request previously blocked initial video
  or tore down an established stream. Telemetry now loads separately, clears stale
  readings on failure and retries without restarting media.
- Losing focus on Windows emits `inactive` even while the window is visible. This
  no longer pauses the camera; hiding/minimizing/backgrounding still does.

The native player uses mpv's low-latency profile with disk caching and read-ahead
disabled, and a 100 ms audio buffer. Audio/video clock synchronization remains enabled.
Recoverable decoder log errors no longer trigger immediate reconnection; end-of-stream,
startup failure or eight seconds without playback timeline progress do. The settings
follow the [mpv low-latency guidance](https://mpv.io/manual/stable/#low-latency-playback).
These settings reduce sources of buffering; they do not establish an exact physical
camera-to-screen or speaker delay.

Validation against pinned package `e82df97` (0.2.1): Windows decoded 1920×1080
video after 2,180 ms and sustained a 90-second muted playback test with 901 timeline
updates and zero stream errors. A separate hardware test passed visible-window
focus changes, background pause/resume and Wi-Fi setup remaining paused. Its live
test harness was corrected to avoid waiting for a rendered frame while paused.
All 161 app tests and 82 camera-package tests passed; app and changed-package-file
analysis passed. Numeric evidence is in the research repo's
`evidence/windows-stream-stability-2026-11-05.json`. This run did not block WAN;
exact physical audio/video delay remains unmeasured and Android hardware playback
still needs confirmation.
The normal Windows release and Android GitHub debug APK were rebuilt successfully
against that pinned dependency; the Windows release was reopened on the live camera.
The owner then confirmed the Windows result: “Much better and stays connected.”
This records the observed improvement in delay and stability without assigning an
unmeasured latency value or uptime duration.

## Camera sound controls — 5 November 2026

Camera sounds are now a first-class local feature on the shared Windows/Android screen.
They use the bundled WAV files and a namespaced temporary camera process, not account
requests or uploaded media. Its timer runs independently of Nestling, the sound loops
until the deadline, and the global microphone/speaker mixer remains unchanged. Volume
changes target only the Nestling PulseAudio stream. Stop validates the runner's command
line and process group before signaling it, so it does not kill other camera audio jobs.

The UI reads sound status every three seconds and restores the current track/volume when
you return. Status/action errors do not interrupt video. Opening, reconnecting or leaving
the screen never automatically starts or stops a sound. Stop remains available when the
current playback status is uncertain. No sound is started until Play sound is pressed.

The package's opt-in `test/manual/sound_live_test.dart` verified muted start, volume update,
status and stop for all four tracks, plus automatic timer expiry with the client closed.
All five hardware tests passed at zero volume. A Pulse inspection separately confirmed
0% output and removal of the stream after Stop. These tests establish control operation;
they do not independently confirm audible quality for every track.

The real Windows Play/Stop buttons were then verified at 0% volume. Playback status
updated and Stop removed the camera's stream/helper. All 163 app tests and 85 package
tests pass; two Windows hardware video/lifecycle checks also pass with sound polling
enabled. Windows release and Android GitHub debug builds succeeded against package
`3c35d4d` (0.2.2). Android hardware sound control remains untested. Findings and numeric
evidence are in the research repo's `evidence/local-sound-controls-2026-11-05.json`.

The owner subsequently reported silent playback despite an active, unmuted Pulse
stream. Package 0.2.3 fixes the missing S5L speaker-enable step: Play saves GPIO 60's
previous state and enables it; Stop, timer expiry and failure cleanup restore that
state. Unknown hardware is rejected instead of assuming the same pin. The owner
confirmed audible Wind during a 10-second test at 20%. Both original pin states,
timer expiry, failed playback and forced cleanup were verified on the camera.
The earlier zero-volume checks proved control operation but missed this physical
speaker requirement. See `evidence/speaker-enable-fix-2026-11-05.json` in research.

Validation for pinned `e3efd11` (0.2.3): all 86 camera-package tests passed with
seven optional skips; the five opt-in sound hardware tests and ten relevant app
tests passed. Windows release and Android GitHub debug builds succeeded. The
updated Windows release was reopened and connected to live video.

## Local sound and possible-cry alerts — 5 November 2026

In **Camera → Sound & cry alerts**, enable **Monitor in background** and allow
notifications. Sound and cry alerts have independent switches. Sound sensitivity
offers Low (louder sounds), Normal, and High (quieter sounds). Recent detections,
monitor health and notification-delivery problems appear in the same card.
Monitoring does not require Listen or live video to remain on. Preferences are
saved per device and restored when Nestling starts. Forgetting a camera stops its
monitor and removes its alert preferences.

This is Nestling's local policy, not a reproduction of Nanit's private final
notification decision:

- Sound requires two fresh above-threshold observations. Low/Normal/High use
  −25/−35/−45 dBFS. These are digital microphone levels, not calibrated room SPL.
- Possible crying requires three consecutive native cry-model scores of at least
  0.70. Scores are read from the camera's existing classifier; generic noise and
  raw `is_alert=false` candidate messages are never relabelled as crying.
- Each alert type repeats at most once a minute. Startup/reconnect/reboot discard
  historical data. Muted microphones and stale data are reported as unavailable.
  An unhealthy monitor sends one interruption notification after 15 seconds.
- General sound alerts pause during camera speaker playback, including sounds
  and talk-back. Cry checks continue; accuracy during playback is unvalidated.

The package's separate per-instance sampler converts microphone PCM to numeric
one-second RMS on the camera. No audio file is retained or uploaded. Only numeric
levels, native probability windows and health metadata are polled, approximately
every two seconds plus request time. An owned-process check protects cleanup;
each helper expires after 45 seconds without renewal. Windows and Android can
monitor independently without stopping each other's helper.

Windows must remain running and awake. Android uses the existing foreground
service/shared Flutter engine with its own persistent monitoring flag and CPU
wake lock. Turning off log sync does not turn off camera monitoring. Turning off
monitoring releases its wake lock while retaining enabled log sync. The optional
**Allow background battery use** action opens Android's system prompt. Both
devices must stay on the camera's LAN. Force-stop, sleep on Windows, Wi-Fi loss,
and Android power restrictions can interrupt alerts. A short locked-screen test
does not establish overnight reliability or survival of every OEM power policy.

### Device-test isolation and deployment incident

The first Android integration deployment replaced the installed GitHub app with
the checkout's older test build. Flutter's automatic uninstall removed the phone's
local log. The owner was informed; the official Nestling 1.5.30 (code 38) APK was
restored. The owner chose to restore their log manually; no PC backup was imported.
Private recovery files remain ignored and are not part of this change.

The `cameraTest` flavor uses app ID `com.babyapp.baby_app.camera_test`, label
**Nestling Camera Test**, and an updater stub. Also, this Flutter SDK can infer the
production namespace before the test APK exists and later target it during test
cleanup. A separate flavor alone is insufficient: prebuild and verify its APK
identity, and disable automatic uninstall. `tool/test_camera_android.ps1` does
these checks. Do not use direct `flutter test --flavor github` on an owner's app.
The production app was restored and its version verified again after testing.

```powershell
# Keep the phone unlocked for launch; lock it after ALERT_BACKGROUND_READY.
./tool/test_camera_android.ps1 -Device <adb-device-id> -Camera <camera-ip>
# Coordinated speech check: wait up to ten minutes, finish after an actual sound
# notification, and retain a short window for inspecting Android's OS notice.
./tool/test_camera_android.ps1 -Device <adb-device-id> -Camera <camera-ip> -Seconds 600 -RequireSound
# Windows opt-in hardware test:
flutter test integration_test/local_alerts_live_test.dart -d windows --dart-define=NANIT_TEST_IP=<camera-ip>
```

The same guarded Android launcher supports `-Test local_camera_latency_test`
for native-player A/B comparisons, `-Test local_camera_listen_test` for repeated
muted/Listen transitions, and `-Test local_camera_lag_test` for transport stalls.
`-Seconds` controls each comparison/soak window. `-TimingVariant baseline` selects
one A/B case; `-TimingImages` explicitly enables private raw BGRA timing stills in
the isolated app's cache. Those images and raw logs must not be committed.

Camera package 0.2.7 removes the silent audio clock while Listen is off. Enabling
Listen starts a fresh synchronized audio/video session; a short loading indicator
is expected when changing modes. Windows uses software decoding to avoid its
hardware copy-back queue. Android retains automatic decoder selection. Background
sound/cry monitoring continues independently. The remaining camera/transport
delay and optical measurement limits are documented in the research repository's
`STREAM_LATENCY.md` and `evidence/baseline-latency-2026-11-05.json`.

The hardware test leaves the camera screen, checks that native levels continue
advancing, and sends an explicitly labelled synthetic cry notification through
the production policy/delivery path. Synthetic probabilities test alert routing;
they do not validate recognition of actual crying.
The optional `-RequireSound` check fails if no real sound notification is delivered
before the deadline. It counts events only after the notification call succeeds;
the ordinary timed background test can legitimately pass with zero sound events.

### Validation results

- Pinned camera package `0a52fdf` (0.2.4), with the local dependency override
  removed: app analysis passed and all 171 app tests passed (two optional skips).
  Windows release, Android GitHub debug and isolated cameraTest debug builds passed.
- Windows: a 180-second observation away from Camera advanced native level time
  by 178 seconds, remained healthy, and delivered one real **Sound detected** alert
  during owner-confirmed speech at Normal sensitivity. A separate labelled
  synthetic fixture passed possible-cry notification delivery. The release app
  was reopened on live video and its real alert controls enabled; monitoring
  reported healthy with both alert types on.
- Samsung SM-S938B (reported Android 17): the 90-second away-from-Camera test
  advanced native level time by 88.99 seconds and passed while Home/background
  and sleep were applied during the window. Android reported foreground service
  ID 4242 and the `Nestling:cameraMonitoring` partial wake lock. After stopping,
  no service remained and Android recorded release of that wake lock. A labelled
  synthetic possible-cry notification call succeeded; this first run captured
  zero acoustic alerts.
- A second Android run through the guarded launcher passed a 120-second window
  with 119 seconds of native level advancement. The phone was locked/backgrounded
  after readiness; the service and wake lock were again removed after Stop.
  Synthetic cry delivery passed and the normal app remained version 1.5.30/code
  38 after cleanup. This window also captured zero acoustic alerts; real Android
  sound-alert delivery was not established until the coordinated check below.
  The isolated normal-app build is provided separately for manual use, without
  importing the owner's log.
- Package validation: 88 tests passed; two simultaneous real-camera sessions
  maintained fresh levels/classifier metadata independently. A forced short-lease
  check removed its helper and Pulse source output after expiry.
- Coordinated Android speech check: the longer `ALERT_REQUIRE_SOUND` test ended
  successfully after 56 seconds, with 56 seconds of native level advancement and
  one real Sound detected notification at Normal sensitivity. The owner confirmed
  speaking. Android's notification record independently showed ID 3000010,
  channel `local_camera_alerts`, title **Sound detected**, and importance 4 while
  keyguard reported `showing=true` and `inputRestricted=true`. Monitoring remained
  healthy and the separate synthetic cry-notification check passed. Stop removed
  the service and released its wake lock. The isolated normal-app APK was put back
  afterward; the production app remained 1.5.30/code 38 and no log was imported.

No camera reboot, pairing, credential reads/deletion, microphone-mixer change,
sound-machine start or breathing action was used for these alert tests. No new
WAN-block experiment was performed. Real-cry sensitivity/false positives, cry
performance during sound playback, overnight Android power management and
reboot/process-restart recovery remain unvalidated on hardware.

## Recovering accumulated stream delay

A three-second test-only transport stall reproduced an advancing but delayed
stream on the local RTSP path. The previous watchdog only detected stopped
playback, so the resumed stream could stay several seconds behind indefinitely.
The player now compares playback progress against a monotonic clock after
startup and requests a fresh connection if it gains more than 1.5 seconds of lag
for three seconds. Brief jitter or a backlog that catches up does not reconnect.
Audio/video synchronization is retained; this fixes accumulated delay rather
than promising zero base latency.

A PC-clock comparison measured roughly 0.8–0.9 seconds on the published Windows
build and about 0.5–1.1 seconds on Android in short samples after reconnecting.
Those measurements are not an overnight guarantee or a physical audio-delay
measurement. The 45-second baseline runs passed on both platforms. The stall
test fails when the new guard is disabled; with it enabled, it checks that a
fresh player decodes again and does not enter a reconnect loop.

```powershell
flutter test integration_test/local_camera_lag_test.dart -d windows --dart-define=NANIT_TEST_IP=<owned-camera-ip>
```

Android hardware tests must continue using the isolated `cameraTest` flavor,
prebuild/verify its actual package ID, and use `--no-uninstall`. Do not deploy
integration tests over the owner's production app.
