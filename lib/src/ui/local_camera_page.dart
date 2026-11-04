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
            const LText(
              'Put the camera in pairing mode with its light flashing. Keep it nearby and close the Nanit app. Choose your camera, then enter a WPA2 Wi-Fi network.',
            ),
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
            if (_searched && _found.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: LText(
                  'No camera found yet. Try again after it joins Wi-Fi, or enter its address from your router’s device list.',
                ),
              ),
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
  bool _configuringWifi = false;
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
    final foreground = state == AppLifecycleState.resumed;
    if (_foreground == foreground) return;
    setState(() {
      _foreground = foreground;
      _muted = true;
      _playing = false;
    });
    if (foreground && !_configuringWifi) {
      unawaited(widget.hub.watch());
    } else {
      unawaited(widget.hub.pause());
    }
  }

  Future<void> _configureWifi() async {
    setState(() {
      _configuringWifi = true;
      _muted = true;
    });
    await widget.hub.pause();
    try {
      await widget.onWifiSetup?.call();
    } finally {
      if (mounted) {
        setState(() => _configuringWifi = false);
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
                    onTap: _configureWifi,
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
