import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nanit_camera/nanit_camera.dart';

import '../local_nanit.dart';
import '../local_talk.dart';
import '../local_camera_alerts.dart';
import '../background.dart';
import '../nanit_integration.dart';
import 'camera/camera_address_dialog.dart';
import 'camera/camera_help.dart';
import 'camera/camera_help_content.dart';
import 'camera/camera_issues.dart';
import 'camera/camera_live_tips.dart';
import 'camera/talk_button.dart';
import 'common.dart';
import 'disclaimer_page.dart';
import 'theme.dart';

class LocalCameraWatch extends StatefulWidget {
  const LocalCameraWatch({
    super.key,
    required this.hub,
    this.onWifiSetup,
    this.onUseAccount,
    this.accountReady = false,
  });
  final LocalNanitHub hub;
  final Future<void> Function()? onWifiSetup;

  /// Switches to watching with the Nanit account, or to signing in when
  /// [accountReady] is false.
  final VoidCallback? onUseAccount;

  /// Whether a Nanit account camera is already set up.
  final bool accountReady;
  @override
  State<LocalCameraWatch> createState() => _LocalCameraWatchState();
}

class _LocalCameraWatchState extends State<LocalCameraWatch>
    with WidgetsBindingObserver {
  bool _muted = true, _foreground = true, _playing = false;
  bool _showingDetails = false;
  String? _playingUrl;
  LocalTalk? _talk;
  String? _talkAddress;

  /// Talk-back for the saved camera. Rebuilt if the camera's address changes.
  LocalTalk? _talkFor(String? address) {
    if (address == null) return null;
    if (_talk == null || _talkAddress != address) {
      _talk?.dispose();
      _talk = LocalTalk(address: address);
      _talkAddress = address;
    }
    return _talk;
  }

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
    if (!foreground) unawaited(_talk?.stop() ?? Future<void>.value());
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
    unawaited(_talk?.stop() ?? Future<void>.value());
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
    // Closes the microphone and the camera speaker stream.
    _talk?.dispose();
    unawaited(widget.hub.pause());
    super.dispose();
  }

  Map<CameraFixAction, VoidCallback> get _fixes => {
    CameraFixAction.retry: () => unawaited(widget.hub.reconnect()),
    CameraFixAction.changeAddress: () => _editAddress(context),
    if (widget.onWifiSetup != null)
      CameraFixAction.setUpWifi: () => _openDetails(widget.onWifiSetup!),
    // When the home network fails, a set-up account camera is one tap away.
    if (widget.accountReady && widget.onUseAccount != null)
      CameraFixAction.useAccount: widget.onUseAccount!,
  };

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
      final t = Theme.of(context).textTheme;
      final s = Theme.of(context).colorScheme;
      final fault = hub.fault;
      final talk = _talkFor(saved.address);
      // Losing the camera connection ends any talk at once.
      if (!ready && talk != null && talk.active) unawaited(talk.stop());
      return ListView(
        padding: EdgeInsets.fromLTRB(
          Space.page,
          Space.sm,
          Space.page,
          Space.xxl + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Row(
            children: [
              Expanded(child: Text(saved.name, style: t.headlineSmall)),
              IconButton(
                tooltip: tr('Tips for the live view'),
                icon: const Icon(Icons.lightbulb_outline),
                onPressed: () => showCameraLiveTips(context),
              ),
              IconButton(
                tooltip: tr('Camera help'),
                icon: const Icon(Icons.help_outline),
                onPressed: () => _openDetails(() => openCameraHelp(context)),
              ),
            ],
          ),
          Row(
            children: [
              Icon(
                playing ? Icons.wifi : Icons.wifi_find,
                size: 20,
                color: s.onSurfaceVariant,
              ),
              const SizedBox(width: Space.sm),
              Flexible(
                child: LText(
                  style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant),
                  playing
                      ? 'Live · Home network'
                      : ready
                      ? 'Opening video…'
                      : hub.state == LocalCameraState.idle
                      ? 'Camera paused'
                      : hub.state == LocalCameraState.retrying
                      ? 'Trying again in a few seconds…'
                      : 'Connecting to your camera…',
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          CameraFirstTimeTips(store: hub.store),
          const SizedBox(height: Space.xs),
          KeepVideoAlive(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Corners.lg),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                // Video letterboxing stays black in every theme.
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
          ),
          const SizedBox(height: Space.md),
          Wrap(
            spacing: Space.md,
            runSpacing: Space.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
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
          if (talk != null) ...[
            const SizedBox(height: Space.md),
            TalkButton(talk: talk, enabled: ready && _foreground),
          ],
          if (ready && _muted)
            Padding(
              padding: const EdgeInsets.only(top: Space.sm),
              child: LText(
                'Muted. Tap Listen to hear the room.',
                style: t.bodySmall?.copyWith(color: s.onSurfaceVariant),
              ),
            ),
          if (fault != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.md),
              child: CameraIssueCard(
                issue: issueForLocalFault(fault),
                detail: hub.problem,
                actions: _fixes,
                compact:
                    fault == LocalCameraFault.roomReadings ||
                    fault == LocalCameraFault.nightLight,
              ),
            )
          else if (hub.problem != null)
            Padding(
              padding: const EdgeInsets.only(top: Space.md),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(Space.lg),
                  child: LText(hub.problem!),
                ),
              ),
            ),
          const SizedBox(height: Space.xl),
          _CameraSounds(hub: hub),
          const SizedBox(height: Space.md),
          CameraAlertsCard(alerts: hub.alerts),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.xs, Space.lg, Space.xs, 0),
            child: LText(
              'Use at your own risk. Camera feeds and alerts can fail or be delayed. Always independently check your child.',
              style: t.bodyMedium?.copyWith(color: s.onSurfaceVariant),
            ),
          ),
          TextButton(
            onPressed: () => showDisclaimer(context),
            child: const LText('Disclaimer & responsibility'),
          ),
          const SizedBox(height: Space.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('In the room'), style: t.titleMedium),
                  const SizedBox(height: Space.md),
                  Wrap(
                    spacing: Space.xl,
                    runSpacing: Space.md,
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
                  const SizedBox(height: Space.sm),
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
          const SizedBox(height: Space.md),
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
                  padding: EdgeInsets.fromLTRB(Space.lg, 0, Space.lg, Space.lg),
                  child: LText(
                    'Video and room readings pause when you leave this screen. Enabled sound and cry alerts keep monitoring while Nestling runs. Motion and breathing alerts are not available in local mode.',
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.settings_ethernet),
                  title: const LText('Change camera address'),
                  subtitle: const LText('If your router gave it a new one'),
                  onTap: () => _editAddress(context),
                ),
                if (widget.onWifiSetup != null)
                  ListTile(
                    leading: const Icon(Icons.wifi),
                    title: const LText('Change Wi-Fi'),
                    subtitle: const LText('New router, Wi-Fi name or password'),
                    onTap: () => _openDetails(widget.onWifiSetup!),
                  ),
                if (widget.onUseAccount != null)
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: LText(
                      widget.accountReady
                          ? 'Watch with Nanit account'
                          : 'Sign in with Nanit',
                    ),
                    subtitle: const LText(
                      'Adds motion alerts. Needs the internet about once a week.',
                    ),
                    onTap: widget.onUseAccount,
                  ),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const LText('Help & troubleshooting'),
                  subtitle: const LText('Search problems and questions'),
                  onTap: () => _openDetails(() => openCameraHelp(context)),
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
    final address = await showCameraAddressDialog(
      context,
      initial: widget.hub.saved!.address,
    );
    if (address == null || !mounted) return;
    try {
      final old = widget.hub.saved!;
      await widget.hub.add(address, name: old.name);
      await widget.hub.reconnect();
    } catch (e) {
      if (mounted) {
        final issue = issueForAddError(e);
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: LText(
              topicFor(
                issue,
                windows:
                    Theme.of(this.context).platform == TargetPlatform.windows,
              ).title,
            ),
            action: SnackBarAction(
              label: tr('More help'),
              onPressed: () =>
                  openCameraHelp(this.context, topicId: issue.name),
            ),
          ),
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
            style: dangerButtonStyle(context),
            onPressed: () => Navigator.pop(context, true),
            child: const LText('Forget'),
          ),
        ],
      ),
    );
    if (yes == true) await widget.hub.forget();
  }
}

class CameraAlertsCard extends StatelessWidget {
  const CameraAlertsCard({super.key, required this.alerts});
  final LocalCameraAlerts alerts;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: alerts,
    builder: (context, _) => Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('Sound & cry alerts'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const LText('Monitor in background'),
              subtitle: const LText(
                'Keep monitoring when you leave the camera screen',
              ),
              value: alerts.enabled,
              onChanged: alerts.changing ? null : alerts.setEnabled,
            ),
            LText(alerts.status ?? 'Monitoring is off'),
            if (alerts.problem != null && !alerts.enabled)
              LText(alerts.problem!),
            if (alerts.notificationProblem != null)
              LText(alerts.notificationProblem!),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const LText('Sound alerts'),
              value: alerts.soundEnabled,
              onChanged: alerts.changing
                  ? null
                  : (v) => alerts.configure(sound: v),
            ),
            DropdownButtonFormField<SoundSensitivity>(
              key: ValueKey(alerts.sensitivity),
              isExpanded: true,
              initialValue: alerts.sensitivity,
              decoration: InputDecoration(labelText: tr('Sound sensitivity')),
              items: const [
                DropdownMenuItem(
                  value: SoundSensitivity.low,
                  child: LText('Low · louder sounds'),
                ),
                DropdownMenuItem(
                  value: SoundSensitivity.normal,
                  child: LText('Normal'),
                ),
                DropdownMenuItem(
                  value: SoundSensitivity.high,
                  child: LText('High · quieter sounds'),
                ),
              ],
              onChanged: alerts.changing
                  ? null
                  : (v) => alerts.configure(level: v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const LText('Cry alerts'),
              subtitle: const LText(
                'Possible crying from sustained camera classification',
              ),
              value: alerts.cryEnabled,
              onChanged: alerts.changing
                  ? null
                  : (v) => alerts.configure(cry: v),
            ),
            const LText(
              'Sound alerts pause while the camera speaker plays audio. Cry checks continue. Alerts repeat at most once a minute for each type.',
            ),
            const SizedBox(height: Space.sm),
            const LText(
              'Stay on the same home network. Windows must remain open and awake. Android shows an ongoing monitoring notification; battery restrictions or force-stopping Nestling can interrupt monitoring.',
            ),
            if (BackgroundSync.batteryExemptSupported && alerts.enabled)
              TextButton(
                onPressed: BackgroundSync.requestBatteryExempt,
                child: const LText('Allow background battery use'),
              ),
            if (alerts.history.isNotEmpty) ...[
              const SizedBox(height: Space.md),
              Text(
                tr('Recent alerts'),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final event in alerts.history.take(3))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    event.kind == LocalAlertKind.unavailable
                        ? Icons.wifi_off
                        : Icons.hearing,
                  ),
                  title: LText(localAlertTitle(event.kind)),
                  trailing: Text(
                    TimeOfDay.fromDateTime(event.at).format(context),
                  ),
                ),
            ],
          ],
        ),
      ),
    ),
  );
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
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.graphic_eq,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: Space.sm),
                Text(
                  tr('Camera sounds'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            LText(
              playing
                  ? '${sound!.track!.label} is playing · ${((sound.remainingSeconds + 59) ~/ 60)} min remaining'
                  : sound == null
                  ? 'Checking camera sounds…'
                  : !sound.supported
                  ? 'Sound playback is unavailable on this camera.'
                  : 'Play a soothing sound through the camera’s speaker.',
            ),
            const SizedBox(height: Space.lg),
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
              const SizedBox(height: Space.lg),
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
            const SizedBox(height: Space.lg),
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
              spacing: Space.md,
              runSpacing: Space.sm,
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
                padding: EdgeInsets.only(top: Space.md),
                child: LinearProgressIndicator(),
              ),
            if (hub.soundProblem != null)
              Padding(
                padding: const EdgeInsets.only(top: Space.md),
                child: LText(hub.soundProblem!),
              ),
            const SizedBox(height: Space.md),
            const LText(
              'Sound continues if you leave this screen, until its timer ends or you tap Stop sound.',
            ),
          ],
        ),
      ),
    );
  }
}

class _Reading extends StatelessWidget {
  const _Reading(this.icon, this.label, this.value);
  final IconData icon;
  final String label, value;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
      const SizedBox(width: Space.sm),
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
