import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../sync.dart';
import 'common.dart';
import 'qr_sync_page.dart';
import 'theme.dart';

void openPeer(BuildContext context, Peer p) => Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => PeerPage(deviceId: p.deviceId)),
);

String versionLabel(String? v) => switch (v) {
  null => 'Not known yet',
  olderVersion => 'Older version',
  _ => v,
};

/// Asks whether to sync with a phone on a different app version.
Future<bool> confirmVersionMismatch(BuildContext context, Peer p) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: context.nest.warn.color),
      title: const LText('Different app versions'),
      content: LText(
        'This phone has version ${AppState.appVersion}, ${p.name.isEmpty ? 'the other phone' : p.name} '
        'has ${versionLabel(p.blockedVersion ?? p.appVersion).toLowerCase()}.\n\n'
        'Different versions may store things differently, so some entries could sync wrongly. '
        'Best is to install the same version on both phones.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const LText('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const LText('Continue anyway'),
        ),
      ],
    ),
  );
  return ok == true;
}

/// Everything about one paired device: versions, what is shared, and recent syncs.
class PeerPage extends StatelessWidget {
  const PeerPage({super.key, required this.deviceId});
  final String deviceId;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final p = app.peers.where((p) => p.deviceId == deviceId).firstOrNull;
    if (p == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: LText('This device is no longer in the hub')),
      );
    }
    final name = p.name.isEmpty ? p.host : p.name;
    final mismatch =
        p.appVersion != null && !AppState.sameFeatures(p.appVersion);
    final here = app.counts;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final nest = context.nest;

    Future<void> sync() async {
      try {
        await app.syncPeer(p);
        if (context.mounted) showMessage(context, 'Synced with $name');
      } on VersionMismatchException {
        if (!context.mounted || !await confirmVersionMismatch(context, p)) {
          return;
        }
        if (context.mounted) await _accept(context, app, p);
      } catch (e) {
        if (context.mounted) showMessage(context, 'Could not sync: $e');
      }
    }

    return Scaffold(
      appBar: AppBar(title: LText(name)),
      body: PageWidth(
        maxWidth: 560,
        child: PullToSync(
          onRefresh: sync,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            // Room for the phone's navigation buttons (e.g. Samsung) below the last item.
            padding: EdgeInsets.fromLTRB(
              Space.page,
              Space.sm,
              Space.page,
              Space.xxl + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.phone_android_rounded),
                  title: LText(name, style: theme.textTheme.titleMedium),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LText(
                        p.host.isEmpty
                            ? 'Address not known yet (synced by QR code)'
                            : '${p.host}:${p.port}',
                      ),
                      const SizedBox(height: Space.xs),
                      _Status(peer: p),
                    ],
                  ),
                ),
              ),
              if (p.blockedVersion != null) ...[
                const SizedBox(height: Space.md),
                _Banner(
                  icon: Icons.pause_circle_outline_rounded,
                  title: 'Syncing is paused',
                  text:
                      'The two phones have different app versions, which may cause sync problems. '
                      'Install the same version on both, or continue anyway.',
                  action: FilledButton(
                    onPressed: () async {
                      if (await confirmVersionMismatch(context, p) &&
                          context.mounted) {
                        await _accept(context, app, p);
                      }
                    },
                    child: const LText('Continue anyway'),
                  ),
                ),
              ] else if (mismatch && p.acceptedVersion != null) ...[
                const SizedBox(height: Space.md),
                _Banner(
                  icon: Icons.warning_amber_rounded,
                  title: 'Syncing despite different versions',
                  text: 'You chose to continue. If entries look wrong, update both phones to the same version.',
                  action: OutlinedButton(
                    onPressed: () => app.pauseForVersion(p),
                    child: const LText('Pause syncing'),
                  ),
                ),
              ],
              const SectionTitle('App version'),
              _Group(
                children: [
                  _Row(label: 'This phone', value: AppState.appVersion),
                  _Row(
                    label: name,
                    value: versionLabel(p.appVersion),
                    trailing: p.appVersion == null
                        ? null
                        : Icon(
                            mismatch
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_rounded,
                            color: mismatch
                                ? nest.warn.color
                                : nest.success.color,
                            size: 20,
                          ),
                  ),
                ],
              ),
              const SectionTitle('What is shared'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.lg,
                    vertical: Space.md,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(child: SizedBox()),
                          SizedBox(width: 80, child: _Head('This phone')),
                          SizedBox(width: 80, child: _Head(name)),
                        ],
                      ),
                      const SizedBox(height: Space.xs),
                      for (final (kind, label, glyph, color) in [
                        ('feed', 'Feeds', Glyphs.feed, nest.feed.color),
                        ('sleep', 'Sleep', Glyphs.sleep, nest.sleep.color),
                        ('nappy', 'Nappies', Glyphs.nappy, nest.nappy.color),
                        ('pill', 'Pill doses', Glyphs.pill, nest.pill.color),
                        ('pump', 'Pumping', Glyphs.pump, nest.pump.color),
                        ('med', 'Pills', Glyphs.pill, nest.pill.color),
                        (
                          'baby',
                          'Babies',
                          Glyphs.baby,
                          scheme.onSurfaceVariant,
                        ),
                        (
                          'routine',
                          'Routines',
                          Glyphs.alarm,
                          scheme.onSurfaceVariant,
                        ),
                        (
                          'completion',
                          'Routines done',
                          Glyphs.heart,
                          scheme.onSurfaceVariant,
                        ),
                        (
                          'growth',
                          'Growth entries',
                          Glyphs.baby,
                          scheme.onSurfaceVariant,
                        ),
                      ])
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: Space.sm,
                          ),
                          child: Row(
                            children: [
                              glyph(20, color),
                              const SizedBox(width: Space.md),
                              Expanded(
                                child: LText(
                                  label,
                                  style: theme.textTheme.bodyLarge,
                                ),
                              ),
                              SizedBox(
                                width: 80,
                                child: _Num('${here[kind] ?? 0}'),
                              ),
                              SizedBox(
                                width: 80,
                                child: _Num(
                                  p.remoteCounts[kind]?.toString() ?? '?',
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.xs,
                  Space.sm,
                  Space.xs,
                  0,
                ),
                child: LText(
                  'Feeds, nappies, pill doses, pills and deletions are shared. Settings, reminders, '
                  'the theme and device names stay on each phone. The counts match once both phones are in sync.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SectionTitle('Last sync'),
              if (p.last == null)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.schedule_rounded),
                    title: LText('Not synced yet'),
                  ),
                )
              else
                _Group(
                  children: [
                    _Row(
                      label: 'When',
                      value: '${ago(p.last!.at)} (${whenLabel(p.last!.at)})',
                    ),
                    _Row(
                      label: 'Started by',
                      value: p.last!.outgoing ? 'This phone' : name,
                    ),
                    _Row(
                      label: 'Sent',
                      value: _amount(
                        p.last!.sent,
                        p.last!.outgoing ? p.last!.newThere : null,
                        'for them',
                      ),
                    ),
                    _Row(
                      label: 'Received',
                      value: _amount(
                        p.last!.received,
                        p.last!.newHereTotal,
                        'here',
                      ),
                    ),
                    if (p.last!.newHereTotal > 0)
                      _Row(label: 'New here', value: _kinds(p.last!.newHere)),
                    if (p.last!.bytes > 0)
                      _Row(label: 'Size', value: _size(p.last!.bytes)),
                  ],
                ),
              const SectionTitle('Recent changes synced'),
              if (p.history.isEmpty)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.history_rounded),
                    title: LText('Nothing has changed in a sync yet'),
                  ),
                )
              else
                ListCard(
                  children: [
                    for (final r in p.history.take(15))
                      ListTile(
                        leading: Icon(
                          r.outgoing
                              ? Icons.north_east_rounded
                              : Icons.south_west_rounded,
                        ),
                        title: LText(
                          [
                            if (r.newHereTotal > 0)
                              '${_kinds(r.newHere)} came in',
                            if (r.newThere > 0) '${r.newThere} sent',
                          ].join(' · '),
                        ),
                        subtitle: LText(
                          '${whenLabel(r.at)} · started by ${r.outgoing ? 'this phone' : name}',
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: Space.xl),
              FilledButton.icon(
                icon: app.syncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync_rounded),
                label: const LText('Sync now'),
                onPressed: app.syncing ? null : sync,
              ),
              const SizedBox(height: Space.sm),
              OutlinedButton.icon(
                icon: const Icon(Icons.qr_code_2_rounded),
                label: const LText('Sync by QR code (no Wi-Fi needed)'),
                onPressed: () => openQrSync(context, peer: p),
              ),
              const SizedBox(height: Space.sm),
              OutlinedButton.icon(
                icon: const Icon(Icons.wifi_find_rounded),
                label: const LText('Find on this Wi-Fi'),
                onPressed: app.syncing
                    ? null
                    : () async {
                        showMessage(
                          context,
                          'Looking for $name on this Wi-Fi...',
                        );
                        final found = await app.findPeer(p, force: true);
                        if (!context.mounted) return;
                        if (found) {
                          showMessage(context, 'Found $name at ${p.host}');
                          await sync();
                        } else {
                          showMessage(
                            context,
                            'Not found. Is $name on the same Wi-Fi with Nestling open?',
                          );
                        }
                      },
              ),
              const SizedBox(height: Space.sm),
              OutlinedButton.icon(
                icon: const Icon(Icons.restart_alt_rounded),
                label: const LText('Send everything again'),
                onPressed: app.syncing
                    ? null
                    : () async {
                        try {
                          await app.resyncEverything(p);
                          if (context.mounted) {
                            showMessage(context, 'Everything sent to $name');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            showMessage(context, 'Could not sync: $e');
                          }
                        }
                      },
              ),
              const SizedBox(height: Space.sm),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: scheme.error),
                icon: const Icon(Icons.link_off_rounded),
                label: const LText('Remove from hub'),
                onPressed: () {
                  app.forgetPeer(p);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _accept(BuildContext context, AppState app, Peer p) async {
    try {
      await app.acceptVersion(p);
      if (context.mounted) showMessage(context, 'Synced with ${p.name}');
    } catch (e) {
      if (context.mounted) showMessage(context, 'Could not sync: $e');
    }
  }

  static String _amount(int total, int? isNew, String where) {
    final records = '$total record${total == 1 ? '' : 's'}';
    return isNew == null ? records : '$records, $isNew new $where';
  }

  static String _kinds(Map<String, int> m) => [
    for (final (k, one, many) in [
      ('feed', 'feed', 'feeds'),
      ('nappy', 'nappy', 'nappies'),
      ('pill', 'pill dose', 'pill doses'),
      ('med', 'pill', 'pills'),
      ('baby', 'baby profile', 'baby profiles'),
      ('routine', 'routine', 'routines'),
      ('completion', 'routine completion', 'routine completions'),
      ('growth', 'growth entry', 'growth entries'),
    ])
      if ((m[k] ?? 0) > 0) '${m[k]} ${tr(m[k] == 1 ? one : many)}',
  ].join(', ');

  static String _size(int bytes) => bytes < 1024
      ? '$bytes bytes'
      : bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(1)} KB'
      : '${(bytes / 1048576).toStringAsFixed(1)} MB';
}

class _Status extends StatelessWidget {
  const _Status({required this.peer});
  final Peer peer;

  @override
  Widget build(BuildContext context) {
    final (
      IconData icon,
      Color color,
      String text,
    ) = peer.blockedVersion != null
        ? (
            Icons.pause_circle_rounded,
            context.nest.warn.color,
            'Paused: different versions',
          )
        : peer.lastError != null
        ? (Icons.sync_problem_rounded, context.nest.warn.color, peer.lastError!)
        : peer.lastSync != null
        ? (
            Icons.check_circle_rounded,
            context.nest.success.color,
            'Synced ${ago(peer.lastSync!)}',
          )
        : (
            Icons.schedule_rounded,
            context.colors.onSurfaceVariant,
            'Not synced yet',
          );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: Space.sm),
        Expanded(
          child: LText(
            text,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: context.colors.onSurface),
          ),
        ),
      ],
    );
  }
}

/// A notice about the sync state: a neutral card with a status icon, a
/// short explanation and the one action that resolves it.
class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.title,
    required this.text,
    required this.action,
  });
  final IconData icon;
  final String title;
  final String text;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: context.nest.warn.color),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: LText(title, style: theme.textTheme.titleMedium),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            LText(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Space.md),
            Align(alignment: AlignmentDirectional.centerEnd, child: action),
          ],
        ),
      ),
    );
  }
}

/// Label/value rows in a card, without dividers.
class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Column(children: children),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.trailing});
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: LText(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: Space.md),
            Flexible(
              flex: 2,
              child: LText(
                value,
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: Space.sm),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => LText(
    text,
    textAlign: TextAlign.end,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
  );
}

class _Num extends StatelessWidget {
  const _Num(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => LText(
    text,
    textAlign: TextAlign.end,
    style: Theme.of(context).textTheme.titleMedium
        ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
  );
}
