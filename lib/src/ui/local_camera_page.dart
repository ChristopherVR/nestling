import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nanit_camera/nanit_camera.dart';

import '../local_nanit.dart';
import '../nanit_integration.dart';
import '../nanit_wifi_setup.dart';
import 'common.dart';

/// Local onboarding is also used to reconnect after changing Wi-Fi.
class LocalCameraSetup extends StatefulWidget {
  const LocalCameraSetup({
    super.key,
    required this.hub,
    required this.onAccount,
    this.onConnected,
    this.setupWifi = false,
  });
  final NanitHub hub;
  final VoidCallback onAccount;
  final VoidCallback? onConnected;
  final bool setupWifi;
  @override
  State<LocalCameraSetup> createState() => _LocalCameraSetupState();
}

class _LocalCameraSetupState extends State<LocalCameraSetup> {
  final _address = TextEditingController(),
      _name = TextEditingController(text: 'Nursery camera');
  final _ssid = TextEditingController(), _password = TextEditingController();
  final _wifi = NanitWifiSetup();
  Map<String, String> _found = {};
  String? _selected, _error;
  bool _bluetooth = false, _busy = false, _searched = false, _hidden = false;

  @override
  void initState() {
    super.initState();
    _bluetooth = widget.setupWifi;
    final saved = widget.hub.local.saved;
    if (saved != null) {
      _name.text = saved.name;
      _address.text = saved.address;
    }
  }

  @override
  void dispose() {
    for (final c in [_address, _name, _ssid, _password]) {
      c.dispose();
    }
    _wifi.dispose();
    super.dispose();
  }

  Future<void> _discover() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final found = await widget.hub.local.discover();
      if (!mounted) return;
      setState(() {
        _found = found;
        _searched = true;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not search the network. Check Wi-Fi and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add([String? ip]) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.hub.useLocalCamera(ip ?? _address.text, name: _name.text);
      if (mounted) widget.onConnected?.call();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is FormatException ? e.message : 'Could not connect. Check the address and that both devices are on the same network.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join() async {
    setState(() => _error = null);
    try {
      final pending = _wifi.provision(
        _selected!,
        _ssid.text,
        _password.text,
        hidden: _hidden,
      );
      _password.clear();
      await pending;
      if (!mounted || !_wifi.joined) return;
      setState(() => _bluetooth = false);
      await _discover();
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _wifi,
    builder: (context, _) {
      final busy = _busy || _wifi.busy;
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.videocam_outlined, size: 52),
          const SizedBox(height: 12),
          Text(
            tr('Your camera, at home'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const LText(
            'Watch and listen over your home network. No Nanit account or internet connection needed.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const LText(
            'First time here? Choose Set up Wi-Fi if your camera has not joined your home network yet.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                icon: const Icon(Icons.wifi),
                label: LText('Already on Wi-Fi'),
              ),
              ButtonSegment(
                value: true,
                icon: const Icon(Icons.bluetooth),
                label: LText('Set up Wi-Fi'),
              ),
            ],
            selected: {_bluetooth},
            onSelectionChanged: busy
                ? null
                : (s) {
                    setState(() {
                      _bluetooth = s.single;
                      _error = null;
                    });
                    if (!_bluetooth) unawaited(_wifi.stopScan());
                  },
          ),
          const SizedBox(height: 20),
          if (_error != null || _wifi.problem != null) ...[
            _Notice(_error ?? _wifi.problem!),
            const SizedBox(height: 12),
          ],
          if (_wifi.joined) ...[
            const _Notice(
              'The camera accepted the Wi-Fi details. Find it on your home network below.',
            ),
            const SizedBox(height: 12),
          ],
          if (_bluetooth) ...[
            const _PairingGuide(),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: busy || _wifi.scanning ? null : _wifi.scan,
              icon: const Icon(Icons.bluetooth_searching),
              label: LText(
                _wifi.scanning ? 'Looking for cameras…' : 'Find nearby camera',
              ),
            ),
            for (final d in _wifi.devices.values)
              Card(
                child: ListTile(
                  leading: Icon(
                    _selected == d.deviceId
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(d.name ?? 'Nanit camera'),
                  subtitle: Text(d.deviceId),
                  onTap: busy
                      ? null
                      : () => setState(() => _selected = d.deviceId),
                ),
              ),
            if (_selected != null) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _ssid,
                enabled: !busy,
                decoration: InputDecoration(labelText: tr('Wi-Fi name')),
                autocorrect: false,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                enabled: !busy,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: tr('Wi-Fi password'),
                  helperText: tr(
                    'Used once to connect your camera. Not saved.',
                  ),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const LText('Hidden network'),
                value: _hidden,
                onChanged: busy ? null : (v) => setState(() => _hidden = v),
              ),
              FilledButton(
                onPressed: busy ? null : _join,
                child: LText(
                  _wifi.busy
                      ? 'Connecting camera to Wi-Fi…'
                      : 'Connect camera to Wi-Fi',
                ),
              ),
              if (_wifi.busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: LText(
                    'Keep the camera nearby. This can take up to two minutes.',
                  ),
                ),
            ],
          ] else ...[
            TextField(
              controller: _name,
              enabled: !busy,
              maxLength: 60,
              decoration: InputDecoration(labelText: tr('Camera name')),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: busy ? null : _discover,
              icon: const Icon(Icons.search),
              label: LText(
                _busy ? 'Connecting…' : 'Find cameras on my network',
              ),
            ),
            for (final e in _found.entries)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.videocam_outlined),
                  title: Text(e.value),
                  subtitle: Text(e.key),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: busy ? null : () => _add(e.key),
                ),
              ),
            if (_searched && _found.isEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LText(
                  'No camera found yet. If it has not joined this network, set up its Wi-Fi first. Otherwise, retry or enter its address from your router’s device list.',
                ),
              ),
              OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => setState(() {
                        _bluetooth = true;
                        _error = null;
                      }),
                icon: const Icon(Icons.bluetooth),
                label: const LText('Set up camera Wi-Fi'),
              ),
            ],
            const SizedBox(height: 20),
            TextField(
              controller: _address,
              enabled: !busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: tr('Camera IP address'),
                hintText: '192.168.1.25',
              ),
              onSubmitted: busy ? null : (_) => _add(),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: busy ? null : () => _add(),
              child: const LText('Connect by address'),
            ),
            const SizedBox(height: 16),
            const LText(
              'Local access has been verified on Nanit Pro firmware 6.58.615. Other firmware may behave differently.',
            ),
          ],
          if (busy || _wifi.scanning)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: LinearProgressIndicator(),
            ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _showCameraHelp(context),
            icon: const Icon(Icons.help_outline),
            label: const LText('Setup help & troubleshooting'),
          ),
          TextButton(
            onPressed: busy ? null : widget.onAccount,
            child: LText(
              widget.setupWifi
                  ? 'Back to camera'
                  : 'Use a Nanit account instead',
            ),
          ),
        ],
      );
    },
  );
}

class LocalCameraWatch extends StatefulWidget {
  const LocalCameraWatch({super.key, required this.hub, this.onWifiSetup});
  final LocalNanitHub hub;
  final Future<void> Function()? onWifiSetup;
  @override
  State<LocalCameraWatch> createState() => _LocalCameraWatchState();
}

class _LocalCameraWatchState extends State<LocalCameraWatch>
    with WidgetsBindingObserver {
  bool _muted = true, _foreground = true, _playing = false;
  bool _showingDetails = false;
  String? _playingUrl;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.hub.watch());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A visible Windows window becomes inactive when another app has focus.
    // Keep its live feed running; hidden/paused still close the connection.
    if (state == AppLifecycleState.inactive) return;
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground == foreground) return;
    setState(() {
      _foreground = foreground;
      _muted = true;
      _playing = false;
    });
    if (foreground && !_showingDetails) {
      unawaited(widget.hub.watch());
    } else {
      unawaited(widget.hub.pause());
    }
  }

  Future<void> _openDetails(Future<void> Function() open) async {
    setState(() {
      _showingDetails = true;
      _muted = true;
    });
    await widget.hub.pause();
    try {
      await open();
    } finally {
      if (mounted) {
        setState(() => _showingDetails = false);
        if (_foreground) await widget.hub.watch();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(widget.hub.pause());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.hub,
    builder: (context, _) {
      final hub = widget.hub, saved = widget.hub.saved;
      if (saved == null) return const SizedBox.shrink();
      final ready = hub.state == LocalCameraState.ready;
      final url = hub.streamUrl;
      final playing = _playing && _playingUrl == url && ready;
      final room = hub.readings;
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(saved.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(playing ? Icons.wifi : Icons.wifi_find, size: 18),
              const SizedBox(width: 8),
              Flexible(
                child: LText(
                  playing
                      ? 'Live · Home network'
                      : ready
                      ? 'Opening video…'
                      : hub.state == LocalCameraState.idle
                      ? 'Camera paused'
                      : 'Connecting to your camera…',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: Colors.black,
                child: _foreground && ready && url != null
                    ? NanitOfflineView(
                        key: ValueKey(url),
                        url: url,
                        muted: _muted,
                        onError: () {
                          _playing = false;
                          unawaited(hub.streamFailed());
                        },
                        onPlaying: () {
                          if (mounted) {
                            setState(() {
                              _playing = true;
                              _playingUrl = url;
                            });
                          }
                        },
                      )
                    : Center(
                        child: hub.state == LocalCameraState.connecting
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Icon(
                                Icons.videocam_off_outlined,
                                color: Colors.white,
                                size: 40,
                              ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: ready && _foreground
                    ? () => setState(() => _muted = !_muted)
                    : null,
                icon: Icon(_muted ? Icons.volume_off : Icons.volume_up),
                label: LText(_muted ? 'Listen' : 'Mute'),
              ),
              OutlinedButton.icon(
                onPressed: hub.state == LocalCameraState.connecting
                    ? null
                    : () => hub.reconnect(),
                icon: const Icon(Icons.refresh),
                label: const LText('Reconnect'),
              ),
            ],
          ),
          if (hub.problem != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: _Notice(hub.problem!),
            ),
          const SizedBox(height: 20),
          _CameraSounds(hub: hub),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('In the room'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 28,
                    runSpacing: 12,
                    children: [
                      _Reading(
                        Icons.thermostat,
                        'Temperature',
                        room?.temperature == null
                            ? '—'
                            : '${room!.temperature!.toStringAsFixed(1)} °C',
                      ),
                      _Reading(
                        Icons.water_drop_outlined,
                        'Humidity',
                        room?.humidity == null
                            ? '—'
                            : '${room!.humidity!.round()}%',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const LText('Night light'),
                    subtitle: room?.nightLight == null
                        ? const LText('Unavailable')
                        : null,
                    value: (room?.nightLight ?? 0) > 0,
                    onChanged:
                        ready && room?.nightLight != null && !hub.changingLight
                        ? (value) => hub.setNightLight(value ? 50 : 0)
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.router_outlined),
                  title: const LText('Local connection'),
                  subtitle: Text(
                    '${saved.address}\n${saved.uid} · ${saved.firmware}',
                  ),
                  isThreeLine: true,
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: LText(
                    'Video and room readings pause when you leave this screen. Local mode does not provide motion, sound or breathing alerts.',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.settings_ethernet),
                  title: const LText('Change camera address'),
                  onTap: () => _editAddress(context),
                ),
                if (widget.onWifiSetup != null)
                  ListTile(
                    leading: const Icon(Icons.wifi),
                    title: const LText('Change Wi-Fi'),
                    onTap: () => _openDetails(widget.onWifiSetup!),
                  ),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const LText('Setup help & troubleshooting'),
                  onTap: () => _openDetails(() => _showCameraHelp(context)),
                ),
                ListTile(
                  leading: const Icon(Icons.link_off),
                  title: const LText('Forget this camera'),
                  subtitle: const LText(
                    'Removes it from Nestling. Does not reset the camera.',
                  ),
                  onTap: () => _forget(context),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  Future<void> _editAddress(BuildContext context) async {
    final controller = TextEditingController(text: widget.hub.saved!.address);
    final address = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const LText('Camera IP address'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const LText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const LText('Connect'),
          ),
        ],
      ),
    );
    // Dialog transition still uses its controller during the closing frame.
    Future<void>.delayed(const Duration(milliseconds: 350), controller.dispose);
    if (address == null || !mounted) return;
    try {
      final old = widget.hub.saved!;
      await widget.hub.add(address, name: old.name);
      await widget.hub.reconnect();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(content: LText('Could not connect to that camera address.')),
        );
      }
    }
  }

  Future<void> _forget(BuildContext context) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const LText('Forget this camera?'),
        content: const LText('You can add it again from your home network.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const LText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const LText('Forget'),
          ),
        ],
      ),
    );
    if (yes == true) await widget.hub.forget();
  }
}

class _CameraSounds extends StatefulWidget {
  const _CameraSounds({required this.hub});
  final LocalNanitHub hub;
  @override
  State<_CameraSounds> createState() => _CameraSoundsState();
}

class _CameraSoundsState extends State<_CameraSounds> {
  NanitSoundTrack _track = NanitSoundTrack.wind;
  int _minutes = 15;
  double _volume = 20;
  bool _draggingVolume = false;

  @override
  Widget build(BuildContext context) {
    final hub = widget.hub;
    final sound = hub.sound;
    final playing = sound?.playing == true;
    final enabled =
        hub.state == LocalCameraState.ready &&
        sound?.supported == true &&
        !hub.changingSound;
    final track = playing ? sound!.track! : _track;
    final volume = playing && !_draggingVolume
        ? sound!.volume.toDouble()
        : _volume;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.graphic_eq),
                const SizedBox(width: 8),
                Text(
                  tr('Camera sounds'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            LText(
              playing
                  ? '${sound!.track!.label} is playing · ${((sound.remainingSeconds + 59) ~/ 60)} min remaining'
                  : sound == null
                  ? 'Checking camera sounds…'
                  : !sound.supported
                  ? 'Sound playback is unavailable on this camera.'
                  : 'Play a soothing sound through the camera’s speaker.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<NanitSoundTrack>(
              key: ValueKey(track),
              initialValue: track,
              decoration: InputDecoration(labelText: tr('Sound')),
              items: [
                for (final item in NanitSoundTrack.values)
                  DropdownMenuItem(value: item, child: LText(item.label)),
              ],
              onChanged: enabled && !playing
                  ? (value) => setState(() => _track = value!)
                  : null,
            ),
            if (!playing) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _minutes,
                decoration: InputDecoration(labelText: tr('Stop after')),
                items: [
                  for (final minutes in [5, 15, 30, 60])
                    DropdownMenuItem(
                      value: minutes,
                      child: LText('$minutes minutes'),
                    ),
                ],
                onChanged: enabled && !playing
                    ? (value) => setState(() => _minutes = value!)
                    : null,
              ),
            ],
            const SizedBox(height: 16),
            LText('Sound volume · ${volume.round()}%'),
            Slider(
              value: volume,
              min: 0,
              max: 100,
              divisions: 20,
              label: '${volume.round()}%',
              onChanged: enabled
                  ? (value) => setState(() {
                      _draggingVolume = true;
                      _volume = value;
                    })
                  : null,
              onChangeEnd: enabled
                  ? (value) async {
                      if (playing) await hub.setSoundVolume(value.round());
                      if (mounted) setState(() => _draggingVolume = false);
                    }
                  : null,
            ),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: enabled && !playing
                      ? () => hub.playSound(
                          _track,
                          _volume.round(),
                          _minutes * 60,
                        )
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const LText('Play sound'),
                ),
                OutlinedButton.icon(
                  // Stop stays available when playback status is uncertain.
                  onPressed:
                      hub.state == LocalCameraState.ready && !hub.changingSound
                      ? hub.stopSound
                      : null,
                  icon: const Icon(Icons.stop),
                  label: const LText('Stop sound'),
                ),
              ],
            ),
            if (hub.changingSound)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
            if (hub.soundProblem != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: LText(hub.soundProblem!),
              ),
            const SizedBox(height: 12),
            const LText(
              'Sound continues if you leave this screen, until its timer ends or you tap Stop sound.',
            ),
          ],
        ),
      ),
    );
  }
}

class _PairingGuide extends StatelessWidget {
  const _PairingGuide();

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Connect your camera for the first time'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const LText(
            '1. Power the camera and keep it within 1–2 metres of this device. Turn on Bluetooth and close the Nanit app on other devices.',
          ),
          const SizedBox(height: 12),
          const LText(
            '2. Press the Wi-Fi pairing button on the back of the camera. Wait for the night light to flash. Pairing does not require a factory reset.',
          ),
          const SizedBox(height: 12),
          const LText(
            '3. In Set up Wi-Fi, tap Find nearby camera, select your camera, then enter your home Wi-Fi name and WPA2 password. Keep this device on that same home network.',
          ),
          const SizedBox(height: 12),
          const LText(
            'Nestling sends the Wi-Fi details over Bluetooth, then looks for the camera on your network. Your Wi-Fi password is not saved.',
          ),
        ],
      ),
    ),
  );
}

Future<void> _showCameraHelp(BuildContext context) async {
  await Navigator.of(context)
      .push<void>(MaterialPageRoute(builder: (_) => const _CameraHelpPage()));
}

class _CameraHelpPage extends StatelessWidget {
  const _CameraHelpPage();

  @override
  Widget build(BuildContext context) {
    final windows = Theme.of(context).platform == TargetPlatform.windows;
    return Scaffold(
      appBar: AppBar(title: const LText('Camera setup help')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const _PairingGuide(),
              const SizedBox(height: 20),
              Text(
                tr('Troubleshooting'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              _HelpTopic(
                title: 'Bluetooth is off or permission was denied',
                text: windows
                    ? 'Open Windows Settings → Bluetooth & devices and turn Bluetooth on. This PC needs a Bluetooth Low Energy adapter. If Bluetooth is unavailable, check the adapter and its driver. Return to Nestling and tap Find nearby camera again.'
                    : 'Turn Bluetooth on. In Android Settings → Apps → Nestling → Permissions, allow Nearby devices. On Android 11 or earlier, also allow Location and turn Location on while scanning. Return to Nestling and tap Find nearby camera again.',
              ),
              const _HelpTopic(
                title: 'My camera does not appear nearby',
                text: 'Check that the camera is powered and its night light is flashing. Keep it within 1–2 metres and close the Nanit app on all other devices. If flashing has stopped, press the Wi-Fi pairing button again, then retry Find nearby camera. You do not need to pair it in the system Bluetooth device list.',
              ),
              const _HelpTopic(
                title: 'The camera could not join Wi-Fi',
                text: 'Check the exact Wi-Fi name and password, including capitals. This setup supports a WPA2 network; use one without a web sign-in page. Enable Hidden network only if your router hides its network name. Keep the camera near your router. If setup was interrupted, enable pairing mode again and retry.',
              ),
              const _HelpTopic(
                title: 'Wi-Fi was accepted but discovery finds nothing',
                text: 'Give the camera a moment to join, then retry Find cameras on my network. Connect this device to the same home network. Guest Wi-Fi, device isolation or a VPN can prevent local discovery. You can also find the camera in your router’s device list and use Connect by address. Internet access is not required to search your home network.',
              ),
              _HelpTopic(
                title: 'Video will not connect or keeps stopping',
                text:
                    'Check the camera power and that both devices can reach each other on your home network. Tap Reconnect. If your router changed the camera’s address, use Change camera address. If you changed routers or Wi-Fi details, use Change Wi-Fi.'
                    '${windows ? ' If Windows asks about network access, allow Nestling on your trusted private network.' : ''}'
                    ' Video pauses when you leave the camera screen or put Nestling in the background.',
              ),
              const _HelpTopic(
                title: 'I can see video but cannot hear audio',
                text: 'Video starts muted. Tap Listen and check this device’s media volume and selected speaker or headphones. Returning to the camera screen starts muted again. Speaking through the camera is not yet available in Nestling.',
              ),
              const _HelpTopic(
                title: 'Playing or stopping camera sounds',
                text: 'Open Camera sounds below the video. Choose Wind, White noise, Waves or Birds, set a volume and timer, then tap Play sound. Volume can change while playing. Sound continues if you leave the screen or close Nestling; return and tap Stop sound, or let the camera’s timer finish. Stop the current sound before choosing another track or timer.',
              ),
              const SizedBox(height: 20),
              const LText(
                'Local camera access has been tested on Nanit Pro firmware 6.58.615. Windows video playback has passed hardware tests. Android playback and the complete Bluetooth setup flow in Nestling still need testing on physical devices.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HelpTopic extends StatelessWidget {
  const _HelpTopic({required this.title, required this.text});
  final String title, text;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    childrenPadding: const EdgeInsets.only(bottom: 16),
    expandedCrossAxisAlignment: CrossAxisAlignment.start,
    title: LText(title),
    children: [Align(alignment: Alignment.centerLeft, child: LText(text))],
  );
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(16), child: LText(text)),
  );
}

class _Reading extends StatelessWidget {
  const _Reading(this.icon, this.label, this.value);
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LText(label),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    ],
  );
}
