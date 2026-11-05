# Nestling privacy policy

_Last updated: 5 November 2026_

Nestling is a baby log for parents and caregivers: feeds, nappies, sleep, habits, routines and
growth and pumping. It is built by an individual developer (ChristopherVR). This policy explains what the app
does with your information. In short: **your log stays on your own devices.**

## What the app stores

Everything you enter (babies' names, birthdays and photos, log entries, notes, habits, routines,
growth measurements and reminders) is saved only in the app's private storage on your device.
Nestling does not require an account and has no advertising, analytics or tracking. The
developer never receives your data. The optional Nanit account connection is described below.

## Your Nanit camera

Local camera mode connects directly to a camera on your home network. It stores the camera's
name, identifier, firmware version and last local IP address in device-local secure storage.
These settings are not shared through the family hub. Video and microphone audio are streamed
for viewing and listening, not recorded or uploaded by Nestling. Audio starts muted.

If you choose Bluetooth Wi-Fi setup, Nestling sends the network name and password directly to
the selected camera in pairing mode. Nestling does not save the Wi-Fi password or send it to a
server. Local mode does not contact Nanit's account service. The camera's own firmware and
internet access are controlled separately by the camera and your router.

If you instead choose **Use a Nanit account instead**, sign-in and camera-token requests go to
Nanit. The session and camera token are stored securely on your device; the password is not
saved. A saved local camera takes precedence and suppresses automatic Nanit token refresh.

## Sharing between your own devices

If you add devices to your family hub, Nestling sends your log directly between those devices:

- **Over your local Wi-Fi network**, protected by the 6-digit code shown on each device. Data is
  not sent through the internet or any server.
- **By QR codes** that one device shows and another scans with its camera.

Devices in the same hub share each other's addresses and codes so they can sync directly. You can
remove a device from the hub at any time in Settings.

## Permissions

- **Camera:** only to scan pairing and sync QR codes. Images are not saved or sent anywhere.
- **Photos / files:** only when you choose a profile or growth photo, or import or export a
  backup. Backups are written to a location you pick.
- **Notifications, alarms and full-screen alerts:** for feed, habit and routine reminders that you
  set up.
- **Bluetooth (nearby devices):** to set up Wi-Fi on your own camera and connect to your own Bluetooth breast pumps, so
  you can control them and log pumping sessions. Nestling reads the pump's status, battery,
  firmware version and session history, and keeps it on your device. Bluetooth scanning is not
  used to work out your location.
- **Network, Wi-Fi state, background service and battery optimisation:** to keep your devices in
  sync on your local network, including while the app is closed if you turn that on, and to
  discover and view your camera locally. Local camera viewing stops when its screen is closed
  or the app goes into the background.

## Children

Nestling is meant for parents and caregivers, not for children to use. Information about your
baby is entered by you and stays on your devices as described above.

## Deleting your data

Uninstalling Nestling deletes its data from that device. Data already synced to other devices in
your hub stays on those devices until it is deleted there or the app is uninstalled.

## Changes and contact

If this policy changes, the updated version will be published at this address. Questions:
open an issue at https://github.com/ChristopherVR/nestling/issues.
