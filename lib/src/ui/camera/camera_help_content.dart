import 'package:flutter/material.dart';

/// Plain-language camera help: every error the camera screens can show maps
/// to one [CameraHelpTopic] here, and the help page and FAQ read the same
/// list. Strings are English source text; widgets pass them through `tr`.
///
/// docs/local-camera.md carries the same content for the website. Keep the
/// two in step when changing either.

/// Something that went wrong (or commonly confuses people), each with its own
/// explanation and fix. The [name] doubles as the help topic id.
enum CameraIssue {
  // Finding the camera on the home network.
  cameraNotFound,
  searchFailed,
  invalidAddress,
  cannotReachAddress,
  notACamera,
  differentCamera,
  unreachable,
  savedDetails,
  // Video and the room.
  videoDidNotStart,
  videoInterrupted,
  roomReadings,
  nightLight,
  noAudio,
  firewall,
  streamLimit,
  noLanAddress,
  // Nanit account mode.
  tokenExpired,
  cloudUnreachable,
  identityChanged,
  cameraRefused,
  // Bluetooth Wi-Fi setup.
  bluetoothOff,
  bluetoothPermission,
  bleNoCameraFound,
  notNanit,
  wifiRejected,
  wifiInterrupted,
  wifiDetailsInvalid,
}

/// What a fix can do for the user right away. Screens offer only the
/// actions they can perform.
enum CameraFixAction {
  searchAgain,
  enterAddress,
  changeAddress,
  setUpWifi,
  retry,
  scanAgain,
  signIn,
  pickAgain,
}

String cameraFixLabel(CameraFixAction action) => switch (action) {
  CameraFixAction.searchAgain => 'Search again',
  CameraFixAction.enterAddress => 'Type the address',
  CameraFixAction.changeAddress => 'Change camera address',
  CameraFixAction.setUpWifi => 'Set up camera Wi-Fi',
  CameraFixAction.retry => 'Try again',
  CameraFixAction.scanAgain => 'Look again',
  CameraFixAction.signIn => 'Sign in again',
  CameraFixAction.pickAgain => 'Pick the camera again',
};

enum CameraHelpSection { network, bluetooth, wifi, video, account, alerts }

String cameraHelpSectionTitle(CameraHelpSection s) => switch (s) {
  CameraHelpSection.network => 'Finding your camera',
  CameraHelpSection.bluetooth => 'Bluetooth setup',
  CameraHelpSection.wifi => 'Joining Wi-Fi',
  CameraHelpSection.video => 'Video, sound and the room',
  CameraHelpSection.account => 'Nanit account mode',
  CameraHelpSection.alerts => 'Alerts and camera sounds',
};

class CameraHelpTopic {
  const CameraHelpTopic({
    required this.id,
    required this.section,
    required this.icon,
    required this.title,
    required this.summary,
    this.steps = const [],
    this.example,
    this.actions = const [],
    this.keywords = '',
    this.serious = true,
  });

  /// A [CameraIssue] name, or a general topic id.
  final String id;
  final CameraHelpSection section;
  final IconData icon;
  final String title;

  /// Why it happened, in a sentence or two.
  final String summary;

  /// What to do, in order.
  final List<String> steps;

  /// A concrete example, e.g. what an address looks like.
  final String? example;
  final List<CameraFixAction> actions;

  /// Extra English words people might search for.
  final String keywords;

  /// False for "this part is unavailable, the rest keeps working" notices.
  final bool serious;

  /// Every user-facing string, for search and translation checks.
  Iterable<String> get texts => [title, summary, ...steps, ?example];
}

class CameraFaq {
  const CameraFaq(this.question, this.answer);
  final String question, answer;
}

/// General topics that are not errors but are asked about.
abstract final class CameraTopicId {
  static const networks = 'networks';
  static const findAddress = 'findAddress';
  static const routerChangedAddress = 'routerChangedAddress';
  static const pairingMode = 'pairingMode';
  static const cameraSounds = 'cameraSounds';
  static const soundCryAlerts = 'soundCryAlerts';
  static const motionAlerts = 'motionAlerts';
}

const cameraAddressExample = '192.168.1.25';

/// The help topics, with Bluetooth/firewall steps for this platform.
List<CameraHelpTopic> cameraHelpTopics({required bool windows}) => [
  // --- Finding the camera ----------------------------------------------------
  const CameraHelpTopic(
    id: CameraTopicId.networks,
    section: CameraHelpSection.network,
    icon: Icons.wifi,
    serious: false,
    title: 'Which Wi-Fi networks work?',
    summary: 'This device and the camera must be on the same home Wi-Fi. Nestling talks to the camera directly inside your home, so it cannot reach it over mobile data or from somewhere else.',
    steps: [
      'Same Wi-Fi: connect this device to the network the camera uses. Mesh systems (several routers or pods with one name) work fine.',
      '2.4 GHz and 5 GHz: if both use the same network name, it does not matter which one this device uses. If your router has separate names, such as “Home” and “Home-5G”, both usually still reach each other.',
      'Guest Wi-Fi does not work: guest networks are usually walled off from your other devices.',
      'Turn off “AP isolation”, “client isolation” or “device isolation” in your router if it is on. It stops devices from seeing each other.',
      'Turn off any VPN on this device while using the camera.',
      'Away from home? Local mode does not work over mobile data. Use the Nanit app for that.',
    ],
    keywords: 'guest network ap isolation client isolation vpn mesh 5ghz 2.4ghz band mobile data away from home same network',
  ),
  const CameraHelpTopic(
    id: CameraTopicId.findAddress,
    section: CameraHelpSection.network,
    icon: Icons.pin_outlined,
    serious: false,
    title: 'Finding the camera’s address',
    summary: 'Every device on your Wi-Fi has an address, called an IP address. It is four numbers separated by dots. Nestling usually finds it for you; you only need it if searching does not work.',
    example: cameraAddressExample,
    steps: [
      'Open your router’s app (for example the app from your internet provider or mesh system), or its web page. That page is often 192.168.1.1 or 192.168.0.1, and the address is usually printed on a sticker under the router.',
      'Find the list of connected devices (often called Devices, Clients or Connected devices).',
      'Look for a device called Nanit, or one whose name starts with N3. Its IP address is shown next to it.',
      'Some versions of the Nanit app also show it in the camera’s settings, under network or camera information.',
      'Type the four numbers and dots exactly, with no spaces and no “http://”.',
    ],
    keywords:
        'ip address router device list dhcp clients where find number dots',
  ),
  const CameraHelpTopic(
    id: CameraTopicId.routerChangedAddress,
    section: CameraHelpSection.network,
    icon: Icons.router_outlined,
    serious: false,
    title: 'My router gave the camera a new address',
    summary: 'Routers can hand out new addresses after a restart or power cut. Nestling notices and searches for your camera by itself.',
    steps: [
      'Wait a moment on the camera screen. Nestling retries every few seconds and searches the network if the old address stops working.',
      'If it still cannot connect, open Change camera address and type the new address from your router’s device list.',
      'To stop it happening again, “reserve” the camera’s address in your router. This setting is often called DHCP reservation, fixed IP or static lease.',
    ],
    actions: [CameraFixAction.changeAddress],
    keywords: 'ip changed new address dhcp reservation static lease restart',
  ),
  const CameraHelpTopic(
    id: 'cameraNotFound',
    section: CameraHelpSection.network,
    icon: Icons.search_off,
    title: 'Your camera was not found on this Wi-Fi',
    summary: 'Nestling looked for the camera on the Wi-Fi this device is using, but nothing answered.',
    steps: [
      'Check the camera is plugged in and its light is on.',
      'Make sure this device is on the same home Wi-Fi as the camera, not the guest network or mobile data.',
      'Turn off any VPN on this device, then search again.',
      'If the camera is new, was reset, or you changed your router or Wi-Fi password, set up the camera’s Wi-Fi first.',
      'Still nothing? Type the camera’s address yourself.',
    ],
    actions: [
      CameraFixAction.searchAgain,
      CameraFixAction.setUpWifi,
      CameraFixAction.enterAddress,
    ],
    keywords: 'not found nothing found empty no cameras discovery search',
  ),
  CameraHelpTopic(
    id: 'searchFailed',
    section: CameraHelpSection.network,
    icon: Icons.wifi_off,
    title: 'This device could not search the network',
    summary: 'Nestling could not use this device’s Wi-Fi to look for cameras. Usually Wi-Fi is off or not connected yet.',
    steps: [
      'Turn on Wi-Fi and connect to your home network.',
      if (windows)
        'If Windows asks whether Nestling may use the network, allow it on private networks.'
      else
        'If your phone says the Wi-Fi has no internet, choose to stay connected anyway. The camera does not need the internet.',
      'Search again.',
    ],
    actions: const [CameraFixAction.searchAgain, CameraFixAction.enterAddress],
    keywords: 'search failed wifi off offline',
  ),
  const CameraHelpTopic(
    id: 'invalidAddress',
    section: CameraHelpSection.network,
    icon: Icons.edit_note,
    title: 'That does not look like a home-network address',
    summary: 'A camera address is four numbers separated by dots. Home networks use addresses that start with 192.168., 10. or 172.16 to 172.31.',
    example: cameraAddressExample,
    steps: [
      'Check for typos: only numbers and dots, no spaces, no letters and no “http://”.',
      'Use the address from your router’s device list, not your internet (public) address from a “what is my IP” website.',
    ],
    actions: [CameraFixAction.enterAddress],
    keywords: 'invalid wrong address typo ipv4 format public',
  ),
  const CameraHelpTopic(
    id: 'cannotReachAddress',
    section: CameraHelpSection.network,
    icon: Icons.portable_wifi_off,
    title: 'Nothing answered at that address',
    summary: 'Nestling tried the address, but no camera answered. The address may be wrong or out of date, or the camera may be off or on another network.',
    steps: [
      'Check each number of the address again.',
      'Routers sometimes give the camera a new address after a restart. Look it up again in your router’s device list.',
      'Make sure this device is on the same home Wi-Fi as the camera.',
      'Try Search again instead of typing the address.',
    ],
    actions: [
      CameraFixAction.retry,
      CameraFixAction.searchAgain,
      CameraFixAction.enterAddress,
    ],
    keywords: 'wrong address no answer timeout connection refused',
  ),
  const CameraHelpTopic(
    id: 'notACamera',
    section: CameraHelpSection.network,
    icon: Icons.devices_other,
    title: 'Something else is using that address',
    summary: 'A device answered at that address, but it is not a supported Nanit camera. It might be a printer, TV or another gadget.',
    steps: [
      'In your router’s device list, look for the device called Nanit or starting with N3, and use its address.',
      'Or tap Search again and let Nestling find it.',
      'Local mode has been tested on the Nanit Pro camera. Other models may not answer.',
    ],
    actions: [CameraFixAction.searchAgain, CameraFixAction.enterAddress],
    keywords: 'not supported wrong device printer not nanit',
  ),
  const CameraHelpTopic(
    id: 'differentCamera',
    section: CameraHelpSection.network,
    icon: Icons.swap_horiz,
    title: 'A different camera answered',
    summary: 'The saved address now belongs to another camera. This happens when your router hands out addresses again, or if you have more than one Nanit. Nestling will not show another camera by mistake.',
    steps: [
      'Open Change camera address and use your camera’s new address, or set it up again to search for it.',
      'Tip: reserve the camera’s address in your router (DHCP reservation) so it stays the same.',
    ],
    actions: [CameraFixAction.changeAddress, CameraFixAction.retry],
    keywords: 'different camera wrong camera serial mismatch two cameras',
  ),
  const CameraHelpTopic(
    id: 'unreachable',
    section: CameraHelpSection.network,
    icon: Icons.wifi_find,
    title: 'Cannot reach the camera right now',
    summary: 'Nestling is not getting an answer from your camera. It keeps trying every few seconds and searches the network for it.',
    steps: [
      'Check the camera is plugged in and its light is on.',
      'Check this device is on the home Wi-Fi, not guest Wi-Fi or mobile data, and that any VPN is off.',
      'If your router restarted, the camera may have a new address. If Nestling does not find it within a minute, use Change camera address.',
      'If you changed your Wi-Fi name or password, use Change Wi-Fi to give the camera the new details.',
    ],
    actions: [
      CameraFixAction.retry,
      CameraFixAction.changeAddress,
      CameraFixAction.setUpWifi,
    ],
    keywords: 'offline unreachable cannot connect camera off disconnected',
  ),
  const CameraHelpTopic(
    id: 'savedDetails',
    section: CameraHelpSection.network,
    icon: Icons.restore,
    title: 'Saved camera details could not be loaded',
    summary: 'This device’s saved camera details could not be read. Nothing on the camera has changed.',
    steps: ['Set up the camera in Nestling again. It takes a minute.'],
    keywords: 'saved details lost storage',
  ),
  // --- Video, sound and the room ----------------------------------------------
  const CameraHelpTopic(
    id: 'videoDidNotStart',
    section: CameraHelpSection.video,
    icon: Icons.videocam_off_outlined,
    title: 'The camera answered, but video did not start',
    summary: 'The camera is reachable, but its video and audio did not start in time. It is usually busy for a moment after starting up.',
    steps: [
      'Wait half a minute, then tap Reconnect.',
      'If it keeps happening, unplug the camera for 10 seconds, plug it back in, wait for its light, then tap Reconnect.',
    ],
    actions: [CameraFixAction.retry],
    keywords: 'black screen no picture video not starting',
  ),
  const CameraHelpTopic(
    id: 'videoInterrupted',
    section: CameraHelpSection.video,
    icon: Icons.sync_problem,
    title: 'Video stopped',
    summary: 'The video connection dropped. Nestling reconnects by itself, usually within a few seconds.',
    steps: [
      'Wait a moment; you do not need to do anything.',
      'If it drops often, the Wi-Fi may be weak where the camera or this device is. Try moving closer to the router, or add a mesh point near the nursery.',
      'Large downloads or video calls on the same Wi-Fi can also cause drops.',
    ],
    actions: [CameraFixAction.retry],
    keywords: 'video stopped freezes drops lag delay buffering',
  ),
  const CameraHelpTopic(
    id: 'roomReadings',
    section: CameraHelpSection.video,
    icon: Icons.thermostat,
    serious: false,
    title: 'Temperature and humidity are unavailable',
    summary: 'The room readings did not arrive this time. Video keeps working, and Nestling tries again every 15 seconds.',
    steps: ['If it keeps showing for several minutes, tap Reconnect.'],
    actions: [CameraFixAction.retry],
    keywords: 'temperature humidity readings missing dash',
  ),
  const CameraHelpTopic(
    id: 'nightLight',
    section: CameraHelpSection.video,
    icon: Icons.lightbulb_outline,
    serious: false,
    title: 'The night light did not change',
    summary: 'The camera did not confirm the night light change. Video keeps working.',
    steps: ['Wait a few seconds, then try the switch again.'],
    keywords: 'night light lamp',
  ),
  CameraHelpTopic(
    id: 'noAudio',
    section: CameraHelpSection.video,
    icon: Icons.volume_off,
    serious: false,
    title: 'I can see video but cannot hear anything',
    summary: 'Video always starts muted so it never wakes anyone by surprise. Sound plays only after you tap Listen.',
    steps: [
      'Tap Listen under the video. It changes to Mute while sound is on.',
      'Turn up this device’s media volume, not the ringer volume.',
      if (windows)
        'Check the Windows sound output (speaker icon on the taskbar) is the speaker or headset you expect.'
      else
        'If headphones or a Bluetooth speaker are connected, the sound plays there.',
      'Leaving the camera screen mutes it again, so tap Listen each time you come back.',
      'Talking to your baby through the camera is not available in Nestling yet.',
    ],
    keywords: 'no sound audio silent listen mute volume speaker hear talk back',
  ),
  CameraHelpTopic(
    id: 'firewall',
    section: CameraHelpSection.video,
    icon: Icons.shield_outlined,
    title: 'The camera did not send video',
    summary: 'The camera agreed to send video, but none arrived. Something on this device, usually a firewall or VPN, may be blocking it.',
    steps: [
      if (windows) ...[
        'Open Windows Security, then Firewall & network protection, then Allow an app through firewall. Make sure Nestling is allowed on Private networks.',
        'In Windows Settings, open Network & internet, choose your Wi-Fi and set it to Private network.',
      ] else
        'Turn off any VPN, firewall or ad-blocking app on this phone.',
      'Tap Try again.',
    ],
    actions: const [CameraFixAction.retry],
    keywords: 'firewall blocked windows defender vpn no video private network',
  ),
  const CameraHelpTopic(
    id: 'streamLimit',
    section: CameraHelpSection.video,
    icon: Icons.groups_outlined,
    title: 'The camera is busy with other viewers',
    summary: 'A Nanit camera only streams to a few apps at the same time. When it is full, it turns new viewers away (the camera answers with error 403).',
    steps: [
      'Close the Nanit app on other phones and tablets, or close Nestling on another device.',
      'Wait about a minute, then tap Try again.',
    ],
    actions: [CameraFixAction.retry],
    keywords: '403 stream limit too many viewers busy other phones',
  ),
  const CameraHelpTopic(
    id: 'noLanAddress',
    section: CameraHelpSection.video,
    icon: Icons.wifi_off,
    title: 'This device is not on the camera’s network',
    summary: 'The camera sends video straight to this device over your home Wi-Fi. This device does not seem to be on that network right now.',
    steps: [
      'Connect to your home Wi-Fi (not guest Wi-Fi or mobile data).',
      'Turn off any VPN.',
      'Tap Try again.',
    ],
    actions: [CameraFixAction.retry],
    keywords: 'not same wifi mobile data different network',
  ),
  // --- Account mode -------------------------------------------------------------
  const CameraHelpTopic(
    id: 'tokenExpired',
    section: CameraHelpSection.account,
    icon: Icons.key_off_outlined,
    title: 'Your camera key needs renewing',
    summary: 'In Nanit account mode, Nanit gives Nestling a camera key that lasts about 7 days. Nestling renews it by itself whenever this device has internet. If it could not renew in time, or you were signed out, the key stops working.',
    steps: [
      'Make sure this device has internet for a moment.',
      'Tap Sign in again and sign in with your Nanit account.',
      'Prefer never needing the internet? Use home network mode instead; it needs no key.',
    ],
    actions: [CameraFixAction.signIn],
    keywords:
        'token expired key signed out weekly 7 days renew internet sign in',
  ),
  const CameraHelpTopic(
    id: 'cloudUnreachable',
    section: CameraHelpSection.account,
    icon: Icons.cloud_off_outlined,
    title: 'Could not reach Nanit to renew the camera key',
    summary: 'Nestling needs the internet for a moment about once a week to renew the camera key. Video keeps working until the date shown under “Works offline until”.',
    steps: [
      'Check this device has internet, then tap Try again.',
      'If the internet is down, video still works until the key runs out.',
    ],
    actions: [CameraFixAction.retry],
    keywords: 'internet down cloud renew offline until',
  ),
  const CameraHelpTopic(
    id: 'identityChanged',
    section: CameraHelpSection.account,
    icon: Icons.gpp_maybe_outlined,
    title: 'The camera’s identity changed',
    summary: 'The camera no longer matches the one Nestling trusted. This happens after a factory reset or when a camera is replaced.',
    steps: [
      'Tap Pick the camera again, then choose it from your Nanit account.',
    ],
    actions: [CameraFixAction.pickAgain],
    keywords: 'certificate identity reset replaced',
  ),
  const CameraHelpTopic(
    id: 'cameraRefused',
    section: CameraHelpSection.account,
    icon: Icons.block,
    title: 'The camera refused this device',
    summary: 'The camera did not accept Nestling’s key, usually because it has expired or the camera was moved to another account.',
    steps: ['Tap Sign in again.'],
    actions: [CameraFixAction.signIn],
    keywords: 'refused unauthorized 401',
  ),
  // --- Bluetooth ------------------------------------------------------------------
  const CameraHelpTopic(
    id: CameraTopicId.pairingMode,
    section: CameraHelpSection.bluetooth,
    icon: Icons.bluetooth_searching,
    serious: false,
    title: 'Putting the camera in pairing mode',
    summary: 'The camera only listens for Wi-Fi details while it is in pairing mode. You can tell because its night light flashes.',
    steps: [
      'Plug the camera in and wait until it has started (about a minute).',
      'Press the Wi-Fi pairing button on the back of the camera.',
      'Wait for the night light to start flashing. This does not reset or erase the camera.',
      'Pairing mode ends after a few minutes. If the light stops flashing, press the button again.',
    ],
    keywords: 'pairing mode button back flashing light blinking',
  ),
  CameraHelpTopic(
    id: 'bluetoothOff',
    section: CameraHelpSection.bluetooth,
    icon: Icons.bluetooth_disabled,
    title: 'Bluetooth is off',
    summary: 'Nestling sends your Wi-Fi details to the camera over Bluetooth, so Bluetooth needs to be on for this step only.',
    steps: [
      if (windows)
        'Open Windows Settings, then Bluetooth & devices, and turn Bluetooth on.'
      else
        'Swipe down from the top of the screen and turn on Bluetooth.',
      'Come back to Nestling and tap Look again.',
    ],
    actions: const [CameraFixAction.scanAgain],
    keywords: 'bluetooth off disabled',
  ),
  CameraHelpTopic(
    id: 'bluetoothPermission',
    section: CameraHelpSection.bluetooth,
    icon: Icons.lock_outline,
    title: 'Nestling cannot use Bluetooth',
    summary: windows
        ? 'Windows did not let Nestling scan with Bluetooth. This PC needs Bluetooth Low Energy (most PCs from the last ten years have it).'
        : 'Your phone has not given Nestling permission to find nearby devices.',
    steps: [
      if (windows) ...[
        'Open Windows Settings, then Bluetooth & devices, and check Bluetooth is on.',
        'If there is no Bluetooth switch, the adapter or its driver is missing. Check Device Manager, or use a USB Bluetooth adapter.',
      ] else ...[
        'Open Android Settings, then Apps, then Nestling, then Permissions.',
        'Allow Nearby devices.',
        'On Android 11 or older, also allow Location and turn Location on while you set up.',
      ],
      'Come back to Nestling and tap Look again.',
    ],
    actions: const [CameraFixAction.scanAgain],
    keywords:
        'bluetooth permission denied nearby devices location adapter driver',
  ),
  const CameraHelpTopic(
    id: 'bleNoCameraFound',
    section: CameraHelpSection.bluetooth,
    icon: Icons.bluetooth_searching,
    title: 'No camera found nearby',
    summary: 'Nestling looked for 15 seconds but no camera in pairing mode answered.',
    steps: [
      'Check the night light is flashing. If not, press the Wi-Fi pairing button on the back again.',
      'Hold this device within 1–2 metres of the camera.',
      'Close the Nanit app on every phone and tablet. It can hold on to the camera’s Bluetooth.',
      'You do not need to pair the camera in your phone’s Bluetooth settings. If you did, remove it there.',
      'Tap Look again.',
    ],
    actions: [CameraFixAction.scanAgain],
    keywords: 'bluetooth no camera nearby not found scan',
  ),
  const CameraHelpTopic(
    id: 'notNanit',
    section: CameraHelpSection.bluetooth,
    icon: Icons.device_unknown,
    title: 'That device is not a camera in setup mode',
    summary: 'The device you picked did not offer Nanit Wi-Fi setup. Its pairing mode may have ended.',
    steps: [
      'Press the Wi-Fi pairing button on the back of the camera again.',
      'Tap Look again and pick the camera whose name starts with Nanit_.',
    ],
    actions: [CameraFixAction.scanAgain],
    keywords: 'wrong device setup service',
  ),
  // --- Wi-Fi ----------------------------------------------------------------------
  const CameraHelpTopic(
    id: 'wifiRejected',
    section: CameraHelpSection.wifi,
    icon: Icons.wifi_password,
    title: 'The camera could not join your Wi-Fi',
    summary: 'The camera got the details but could not connect. Most often the password has a typo, or the network type is not supported.',
    steps: [
      'Check the Wi-Fi name and password exactly, including capital letters and spaces.',
      'Use a home network with a password (WPA2). Networks with a sign-in web page, like hotel Wi-Fi, do not work. If your router is set to “WPA3 only”, switch it to “WPA2/WPA3”.',
      'If your router has separate 2.4 GHz and 5 GHz names, try the 2.4 GHz one. It reaches further through walls.',
      'Only turn on Hidden network if your router hides its name.',
      'Press the pairing button again so the light flashes, then retry.',
    ],
    keywords: 'wifi join failed wrong password status wpa2 wpa3 2.4ghz 5ghz hidden ssid',
  ),
  const CameraHelpTopic(
    id: 'wifiInterrupted',
    section: CameraHelpSection.wifi,
    icon: Icons.bluetooth_disabled,
    title: 'Wi-Fi setup stopped part-way',
    summary: 'The Bluetooth connection to the camera ended before setup finished. This is common if the camera is too far away or its pairing mode ended.',
    steps: [
      'Keep this device within 1–2 metres of the camera.',
      'Keep Nestling open with the screen on until setup finishes (up to two minutes).',
      'Press the Wi-Fi pairing button again so the light flashes, then go back and look for the camera again.',
    ],
    actions: [CameraFixAction.scanAgain],
    keywords: 'interrupted timeout disconnected setup stopped',
  ),
  const CameraHelpTopic(
    id: 'wifiDetailsInvalid',
    section: CameraHelpSection.wifi,
    icon: Icons.password,
    title: 'Check the Wi-Fi name and password',
    summary: 'The Wi-Fi name must be 1 to 32 characters. The password must be 8 to 63 characters, which is what home routers use.',
    steps: [
      'You can find both on your router’s sticker or in its app, unless someone changed them.',
      'Nothing was sent to the camera yet, so just correct them and try again.',
    ],
    keywords: 'password too short ssid name length',
  ),
  // --- Alerts and sounds ------------------------------------------------------------
  const CameraHelpTopic(
    id: CameraTopicId.cameraSounds,
    section: CameraHelpSection.alerts,
    icon: Icons.graphic_eq,
    serious: false,
    title: 'Playing soothing sounds',
    summary: 'Camera sounds play Wind, White noise, Waves or Birds through the camera’s own speaker.',
    steps: [
      'Choose a sound, a volume and how long it should play (5 to 60 minutes), then tap Play sound.',
      'You can change the volume while it plays.',
      'It keeps playing if you leave the screen or close Nestling. The camera stops it when the time is up, or tap Stop sound.',
      'To change track or timer, stop the current sound first.',
    ],
    keywords: 'white noise sound machine soothing lullaby speaker timer',
  ),
  const CameraHelpTopic(
    id: CameraTopicId.soundCryAlerts,
    section: CameraHelpSection.alerts,
    icon: Icons.notifications_active_outlined,
    serious: false,
    title: 'Sound and cry alerts',
    summary: 'Nestling can keep listening in the background and notify you about loud sounds or possible crying, even when you leave the camera screen.',
    steps: [
      'Under Sound & cry alerts, turn on Monitor in background and allow notifications.',
      'Choose Sound alerts, Cry alerts, or both, and a sound sensitivity. High catches quieter sounds.',
      'Keep this device on the home Wi-Fi. On Windows, keep the PC on and awake. On Android, allow background battery use.',
      'A “monitoring interrupted” alert means Nestling lost the camera, not that the room is quiet.',
      'Possible-crying alerts are a best guess and can be wrong. Always check on your baby yourself.',
    ],
    keywords: 'alert notification cry crying background monitor battery',
  ),
  const CameraHelpTopic(
    id: CameraTopicId.motionAlerts,
    section: CameraHelpSection.alerts,
    icon: Icons.directions_run,
    serious: false,
    title: 'Motion alerts are simpler than in the Nanit app',
    summary: 'Motion alerts are only available in Nanit account mode. They react to how much the picture changes, not to Nanit’s cloud analysis of your baby’s movement.',
    steps: [
      'Shadows, a night light switching or a moving mobile can count as motion.',
      'Use Motion sensitivity: Low ignores small changes, High reacts to small ones.',
      'Breathing monitoring and sleep insights are not available in Nestling.',
    ],
    keywords: 'motion movement sensitivity false alerts breathing sleep',
  ),
];

/// Questions people ask before and after setting up.
const cameraFaq = <CameraFaq>[
  CameraFaq(
    'What does home network mode do?',
    'It shows live video and sound from your Nanit camera, the room temperature and humidity, the night light, soothing sounds, and optional sound and cry alerts. Everything travels over your own Wi-Fi, straight from the camera to this device.',
  ),
  CameraFaq(
    'What does it not do, compared with the Nanit app?',
    'No watching away from home, no recordings or video history, no sleep reports, no breathing monitoring, no motion alerts and no talking through the camera. Keep the Nanit app for those.',
  ),
  CameraFaq(
    'Do I need the internet?',
    'Not in home network mode. Once set up, it works with the internet switched off. Nanit account mode is different: it needs the internet for a moment about once a week.',
  ),
  CameraFaq(
    'Why does account mode need the internet about once a week?',
    'In account mode the camera only accepts a key signed by Nanit, and each key lasts about 7 days. Nestling renews it by itself whenever it can. If it cannot reach Nanit for a week, video stops until you are online again.',
  ),
  CameraFaq(
    'Does my video go to the cloud?',
    'Nestling does not upload your video or sound anywhere. It goes from the camera to this device over your Wi-Fi. The camera itself may still talk to Nanit if it has internet; Nestling does not change that.',
  ),
  CameraFaq(
    'Is my Wi-Fi password saved?',
    'No. During setup it is sent once to the camera over Bluetooth and then forgotten.',
  ),
  CameraFaq(
    'Can I keep using the Nanit app?',
    'Yes. Nestling does not change your Nanit account or subscription. Close the Nanit app while you set up the camera’s Wi-Fi, and remember the camera only streams to a few apps at once.',
  ),
  CameraFaq(
    'Can two phones watch at the same time?',
    'Yes, if both are on the home Wi-Fi. Set up the camera in Nestling on each device. The camera limits how many apps can watch at once.',
  ),
  CameraFaq(
    'Which cameras work?',
    'Home network mode has been tested on the Nanit Pro camera with firmware 6.58.615. Other models or firmware may not work or may behave differently.',
  ),
  CameraFaq(
    'Does it work with mesh Wi-Fi, 5 GHz or a VPN?',
    'Mesh Wi-Fi works. 2.4 GHz and 5 GHz both work as long as they are the same home network. Guest networks and VPNs usually block it.',
  ),
  CameraFaq(
    'Does it use a lot of battery or data?',
    'Live video uses Wi-Fi only, never mobile data, and pauses when you leave the camera screen. Background alerts use some battery because Nestling keeps listening.',
  ),
  CameraFaq(
    'Can I rely on it as a baby monitor?',
    'Treat it as a convenience, not a safety device. Video and alerts can fail or arrive late, for example if the Wi-Fi drops. Always check on your baby yourself.',
  ),
];
