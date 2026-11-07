import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:nanit_camera/nanit_camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../nanit_integration.dart';
import '../../recording.dart';
import '../common.dart';
import '../theme.dart';

/// Where recordings live: `<app documents>/Recordings`.
Future<RecordingStore> openRecordingStore() async {
  final docs = await getApplicationDocumentsDirectory();
  return RecordingStore(
    Directory('${docs.path}${Platform.pathSeparator}Recordings'),
  );
}

/// Words for each thing that can go wrong while recording.
String recordingProblemText(RecordingProblem problem) => tr(switch (problem) {
  RecordingProblem.notLive =>
    'There is no video to record yet. Wait for the picture, then try again.',
  RecordingProblem.streamDropped => 'The video stopped, so the recording was stopped. What was captured is saved.',
  RecordingProblem.storage => 'The recording stopped because it could not be written. Check the free space on this device. What was captured is saved.',
  RecordingProblem.limit =>
    'The recording reached its size or time limit and was saved.',
  RecordingProblem.failed =>
    'Could not start the recording. Check the free space on this device.',
  RecordingProblem.empty => 'Nothing was recorded.',
});

/// Records through libmpv's `stream-record`, which copies the incoming
/// stream to a file without re-encoding. An empty path stops it.
class MpvRecordingSink implements RecordingSink {
  MpvRecordingSink(this._player);
  final Player _player;

  @override
  Future<void> setRecordPath(String path) async {
    final native = _player.platform;
    if (native is! NativePlayer) throw StateError('No native player');
    await native.setProperty('stream-record', path);
  }
}

/// The Nanit live picture with a Record button, a running timer and a link
/// to the saved recordings. Owns the recorder; recording ends when this
/// leaves the screen or the stream drops.
class RecordableCameraView extends StatefulWidget {
  const RecordableCameraView({super.key, required this.stream, this.store});
  final NanitLiveStream stream;

  /// Injected for tests; the app documents' `Recordings` folder otherwise.
  final RecordingStore? store;

  @override
  State<RecordableCameraView> createState() => _RecordableCameraViewState();
}

class _RecordableCameraViewState extends State<RecordableCameraView> {
  RecordingController? _controller;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    widget.stream.addListener(_onStream);
    unawaited(_open());
  }

  Future<void> _open() async {
    final store = widget.store ?? await openRecordingStore();
    if (_closed) return;
    final c = RecordingController(store: store)..addListener(_onRecorder);
    setState(() => _controller = c);
  }

  void _onStream() {
    final c = _controller;
    if (c != null &&
        c.recording &&
        widget.stream.state != NanitLiveState.live) {
      unawaited(c.stop(reason: RecordingProblem.streamDropped));
    }
  }

  void _onRecorder() {
    final c = _controller;
    if (!mounted || c == null) return;
    final problem = c.problem;
    if (problem != null) {
      c.clearProblem();
      showMessage(context, recordingProblemText(problem));
    }
    setState(() {});
  }

  @override
  void dispose() {
    _closed = true;
    widget.stream.removeListener(_onStream);
    final c = _controller;
    if (c != null) {
      c.removeListener(_onRecorder);
      // Close the file before the player and the controller go away.
      unawaited(c.stop(quiet: true).whenComplete(c.dispose));
    }
    super.dispose();
  }

  Widget _player(BuildContext context, String url, bool muted) =>
      _RecordedPlayer(
        key: ValueKey(url),
        url: url,
        muted: muted,
        controller: _controller,
      );

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NanitCameraView(
          stream: widget.stream,
          label: nanitVideoLabel,
          playerBuilder: _player,
        ),
        const SizedBox(height: Space.sm),
        Row(
          children: [
            if (c != null) Expanded(child: _RecordButton(controller: c)),
            const SizedBox(width: Space.sm),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => RecordingsPage(store: c?.store),
                ),
              ),
              icon: const Icon(Icons.video_library_outlined),
              label: const LText('Recordings'),
            ),
          ],
        ),
      ],
    );
  }
}

/// A clear Record / Stop button under the video. While recording it says so,
/// shows how long, and is the obvious thing to press to stop.
class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.controller});
  final RecordingController controller;

  @override
  Widget build(BuildContext context) {
    final on = controller.recording;
    final scheme = Theme.of(context).colorScheme;
    void press() => unawaited(on ? controller.stop() : controller.start());
    if (!on) {
      return FilledButton.tonalIcon(
        onPressed: press,
        icon: const Icon(Icons.fiber_manual_record_outlined),
        label: const LText('Record'),
      );
    }
    return FilledButton.icon(
      onPressed: press,
      icon: const Icon(Icons.stop_rounded),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // The one place the error colour appears: the recording dot.
          Icon(Icons.fiber_manual_record, size: 14, color: scheme.error),
          const SizedBox(width: Space.xs),
          Flexible(
            child: Text(
              '${tr('Stop recording')} · '
              '${formatRecordingDuration(controller.elapsed)}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// media_kit (libmpv) tuned for a live LAN feed (no cache, small probe),
/// owned by the app so it can record the stream.
class _RecordedPlayer extends StatefulWidget {
  const _RecordedPlayer({
    super.key,
    required this.url,
    required this.muted,
    required this.controller,
  });
  final String url;
  final bool muted;
  final RecordingController? controller;

  @override
  State<_RecordedPlayer> createState() => _RecordedPlayerState();
}

class _RecordedPlayerState extends State<_RecordedPlayer> {
  late final Player _player = Player(
    configuration: const PlayerConfiguration(
      title: 'Nanit',
      bufferSize: 4 * 1024 * 1024,
    ),
  );
  late final VideoController _video = VideoController(_player);
  late final MpvRecordingSink _sink = MpvRecordingSink(_player);
  RecordingController? _attachedTo;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    final native = _player.platform;
    if (native is NativePlayer) {
      for (final (k, v) in const [
        ('profile', 'low-latency'),
        ('cache', 'no'),
        ('demuxer-lavf-probesize', '65536'),
        ('demuxer-lavf-analyzeduration', '0.5'),
      ]) {
        try {
          await native.setProperty(k, v);
        } catch (_) {
          // Older libmpv without the option: defaults still play.
        }
      }
    }
    await _player.setVolume(widget.muted ? 0 : 100);
    await _player.open(Media(widget.url));
    _attach();
  }

  void _attach() {
    final c = widget.controller;
    if (!mounted || c == null || identical(c, _attachedTo)) return;
    _attachedTo = c;
    c.attach(_sink);
  }

  @override
  void didUpdateWidget(_RecordedPlayer old) {
    super.didUpdateWidget(old);
    if (old.muted != widget.muted) {
      unawaited(_player.setVolume(widget.muted ? 0 : 100));
    }
    // The recorder is created a moment after the first frame.
    if (widget.controller != null) _attach();
  }

  @override
  void dispose() {
    final c = _attachedTo;
    final done = c == null ? Future<void>.value() : c.detach(_sink);
    // The recording file is closed before the player goes away.
    unawaited(done.whenComplete(_player.dispose));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Video(controller: _video, controls: NoVideoControls, fit: BoxFit.contain);
}

// --- Recordings list ------------------------------------------------------

class RecordingsPage extends StatefulWidget {
  const RecordingsPage({super.key, this.store});

  /// Injected for tests; the app documents' `Recordings` folder otherwise.
  final RecordingStore? store;

  @override
  State<RecordingsPage> createState() => _RecordingsPageState();
}

class _RecordingsPageState extends State<RecordingsPage> {
  RecordingStore? _store;
  List<Recording>? _items;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final store = _store ??= widget.store ?? await openRecordingStore();
    final items = await store.list();
    if (mounted) setState(() => _items = items);
  }

  Future<void> _delete(Recording r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const LText('Delete this recording?'),
        content: const LText('It is removed from this device for good.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const LText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const LText('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _store!.delete(r.path);
    await _load();
  }

  Future<void> _share(Recording r) async {
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(r.path, mimeType: 'video/mp4')]),
      );
    } catch (_) {
      if (mounted) showMessage(context, 'Could not share this recording.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const LText('Recordings')),
      body: PageWidth(
        maxWidth: 720,
        child: items == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(Space.page),
                children: [
                  LText(
                    'Recordings stay on this device. Nothing is uploaded.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Space.md),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(Space.xl),
                      child: Center(
                        child: LText(
                          'No recordings yet. Tap the record button on the live video.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ListCard(
                      children: [
                        for (final r in items)
                          RecordingTile(
                            recording: r,
                            onWatch: () => Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    RecordingPlayerPage(path: r.path),
                              ),
                            ),
                            onShare: () => _share(r),
                            onDelete: () => _delete(r),
                          ),
                      ],
                    ),
                ],
              ),
      ),
    );
  }
}

class RecordingTile extends StatelessWidget {
  const RecordingTile({
    super.key,
    required this.recording,
    required this.onWatch,
    required this.onShare,
    required this.onDelete,
  });
  final Recording recording;
  final VoidCallback onWatch, onShare, onDelete;

  @override
  Widget build(BuildContext context) {
    final r = recording;
    final length = r.duration == null
        ? tr('Length unknown')
        : formatRecordingDuration(r.duration!);
    return ListTile(
      leading: const Icon(Icons.movie_outlined),
      title: Text(DateFormat('EEE d MMM, HH:mm').format(r.started)),
      subtitle: Text('$length · ${formatRecordingSize(r.bytes)}'),
      onTap: onWatch,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: tr('Share'),
            icon: const Icon(Icons.share_outlined),
            onPressed: onShare,
          ),
          IconButton(
            tooltip: tr('Delete'),
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// Watches one saved recording with the standard video controls.
class RecordingPlayerPage extends StatefulWidget {
  const RecordingPlayerPage({super.key, required this.path});
  final String path;

  @override
  State<RecordingPlayerPage> createState() => _RecordingPlayerPageState();
}

class _RecordingPlayerPageState extends State<RecordingPlayerPage> {
  late final Player _player = Player();
  late final VideoController _video = VideoController(_player);
  bool _failed = false;
  StreamSubscription<String>? _errors;

  @override
  void initState() {
    super.initState();
    _errors = _player.stream.error.listen((_) {
      if (mounted) setState(() => _failed = true);
    });
    unawaited(_player.open(Media(widget.path)));
  }

  @override
  void dispose() {
    unawaited(_errors?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const LText('Recording')),
    body: Center(
      child: _failed
          ? const Padding(
              padding: EdgeInsets.all(Space.xl),
              child: LText('This recording could not be opened.'),
            )
          : AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: Colors.black,
                child: Video(controller: _video),
              ),
            ),
    ),
  );
}
