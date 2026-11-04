# Local Nanit camera

Nestling has a local camera mode independent of Nanit sign-in. It uses the owner's camera
on the same private IPv4 network. The verified hardware is a Nanit Pro, firmware 6.58.615.
Other firmware is not yet certified compatible.

## Setup and use

1. Open Camera on Today (enable the card in Settings if hidden), or Settings → Nanit camera.
2. If the camera is already on Wi-Fi, choose **Find cameras on my network**. If multicast
   discovery is filtered, Nestling tries RTSP discovery in each local /24 (up to four
   private interfaces). On a larger subnet, enter an address outside these ranges manually.
3. If it needs Wi-Fi, choose **Set up Wi-Fi**, put it in pairing mode with its light flashing,
   keep it nearby, and close the Nanit app. Scan, select the camera and enter a WPA2 SSID and
   password. A hidden-network toggle is available. No cloud registration is sent.
4. After Wi-Fi is accepted, discover the camera on the LAN or enter its address. Give it a
   name. Nestling verifies its identity before saving it.
5. Video starts muted. **Listen** plays incoming microphone audio on this device. Night light
   toggles between off and 50%; room temperature/humidity update every 15 seconds.

Leaving the screen or backgrounding the app closes the local stream and polling. Returning
starts muted. Reconnection retries every 8 seconds while viewing, with mDNS rediscovery if the
saved address stops working, followed by the bounded RTSP fallback. A different serial at the saved address is rejected. Change the
address or Wi-Fi from the camera details. Forgetting removes Nestling's saved entry only.

Keep the viewing device on the same LAN, without guest/client isolation. LAN access needs
TCP 8081 (maintenance) and 554 (media) to the camera; the in-process player adapter binds only
to loopback on a random port. No inbound LAN stream listener or external Python process is
needed. Internet access is not needed for these operations. Nestling does not itself block
the camera's WAN access; use router policy if it must never reach the internet.

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
  motion/sound detection, breathing monitoring, camera sleep, speaker playback or white noise.
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
