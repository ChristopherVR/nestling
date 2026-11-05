import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import 'common.dart';
import 'peer_page.dart';
import 'settings_page.dart';
import 'theme.dart';

/// The family hub: every device that shares this log, with its sync status.
void openHub(BuildContext context) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => const HubPage()));

/// Shows this device's code and the ways to add another device to the hub.
void openAddDevice(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const AddDevicePage()),
);

const hubExplainer =
    'Everyone in the hub sees the same log. Add a device once, it then shares '
    'with everyone else automatically.';

typedef _Status = ({IconData icon, Color color, String text});

_Status _statusOf(AppState app, Peer p) {
  if (p.blockedVersion != null) {
    return (
      icon: Icons.pause_circle_rounded,
      color: Baby.warn,
      text: 'Paused: different app version',
    );
  }
  if (app.syncing) {
    return (icon: Icons.sync_rounded, color: Baby.primary, text: 'Syncing');
  }
  if (p.lastError != null) {
    return (
      icon: Icons.cloud_off_rounded,
      color: Baby.warn,
      text: p.unreachable || p.learnedFromHub
          ? 'Not reachable right now'
          : p.lastError!,
    );
  }
  if (p.lastSync != null) {
    return (
      icon: Icons.check_circle_rounded,
      color: Baby.ok,
      text: 'Synced ${ago(p.lastSync!)}',
    );
  }
  return (
    icon: Icons.schedule_rounded,
    color: Baby.muted,
    text: p.learnedFromHub ? 'Waiting to connect' : 'Not synced yet',
  );
}

Future<void> _syncNow(BuildContext context, AppState app) async {
  final error = await app.syncAll(force: true);
  if (context.mounted) showMessage(context, error ?? 'Synced');
}

/// "This device" first, then every other member. [detailed] adds the app
/// version and last sync time to each line.
class HubMembers extends StatelessWidget {
  const HubMembers({super.key, this.detailed = false});
  final bool detailed;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListCard(
      children: [
        ListTile(
          leading: const Icon(Icons.phone_android_rounded),
          title: LText(app.deviceName),
          subtitle: LText(
            detailed
                ? 'This device · version ${AppState.appVersion}'
                : 'This device',
          ),
        ),
        if (app.peers.isEmpty)
          ListTile(
            leading: const Icon(Icons.devices_other_rounded),
            title: const LText('No other devices yet'),
            subtitle: const LText('Add a device to share this log.'),
          ),
        for (final p in app.peers)
          _MemberTile(app: app, peer: p, detailed: detailed),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.app,
    required this.peer,
    required this.detailed,
  });
  final AppState app;
  final Peer peer;
  final bool detailed;

  @override
  Widget build(BuildContext context) {
    final st = _statusOf(app, peer);
    final extra = [
      if (detailed && peer.appVersion != null)
        'Version ${versionLabel(peer.appVersion)}',
      if (detailed && peer.lastSync != null)
        'Last sync ${whenLabel(peer.lastSync!)}',
    ];
    return ListTile(
      leading: Icon(st.icon, color: st.color),
      title: LText(
        peer.name.isEmpty
            ? (peer.host.isEmpty ? 'Another device' : peer.host)
            : peer.name,
      ),
      subtitle: LText([st.text, ...extra].join(' · ')),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => openPeer(context, peer),
    );
  }
}

/// Settings section: what the hub is, who is in it, and how to add a device.
class HubSummary extends StatelessWidget {
  const HubSummary({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _Explainer(),
      const SectionTitle('Devices sharing this log'),
      const HubMembers(),
      const SizedBox(height: Space.lg),
      FilledButton.icon(
        icon: const Icon(Icons.group_add_rounded),
        label: const LText('Add a device'),
        onPressed: () => openAddDevice(context),
      ),
      const SizedBox(height: Space.sm),
      OutlinedButton.icon(
        icon: const Icon(Icons.hub_rounded),
        label: const LText('Sync details'),
        onPressed: () => openHub(context),
      ),
    ],
  );
}

/// [hubExplainer] as supporting text under a section title.
class _Explainer extends StatelessWidget {
  const _Explainer();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Space.xs),
    child: LText(
      hubExplainer,
      style: Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

/// Details of every device in the hub, opened from the sync chip.
class HubPage extends StatelessWidget {
  const HubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final recent = [
      for (final p in app.peers)
        for (final r in p.history.take(10)) (peer: p, record: r),
    ]..sort((a, b) => b.record.at.compareTo(a.record.at));
    return Scaffold(
      appBar: AppBar(title: const LText('Family hub')),
      body: PageWidth(
        maxWidth: 560,
        child: PullToSync(
          onRefresh: () => app.peers.isEmpty
              ? Future.value()
              : app.syncAll(force: true).then((_) {}),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              Space.page,
              Space.sm,
              Space.page,
              Space.xxl + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              const _Explainer(),
              const SectionTitle('Devices sharing this log'),
              const HubMembers(detailed: true),
              if (app.peers.isNotEmpty) ...[
                const SectionTitle('Recent sync activity'),
                if (recent.isEmpty)
                  const Card(
                    child: ListTile(
                      leading: Icon(Icons.history_rounded),
                      title: LText('Nothing has changed in a sync yet'),
                    ),
                  )
                else
                  ListCard(
                    children: [
                      for (final (:peer, :record) in recent.take(10))
                        ListTile(
                          leading: Icon(
                            record.outgoing
                                ? Icons.north_east_rounded
                                : Icons.south_west_rounded,
                          ),
                          title: LText(
                            [
                              if (record.newHereTotal > 0)
                                '${record.newHereTotal} came in',
                              if (record.newThere > 0)
                                '${record.newThere} sent',
                            ].join(' · '),
                          ),
                          subtitle: LText(
                            '${peer.name.isEmpty ? peer.host : peer.name} · ${whenLabel(record.at)}',
                          ),
                          onTap: () => openPeer(context, peer),
                        ),
                    ],
                  ),
              ],
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
                onPressed: app.syncing || app.peers.isEmpty
                    ? null
                    : () => _syncNow(context, app),
              ),
              const SizedBox(height: Space.sm),
              OutlinedButton.icon(
                icon: const Icon(Icons.group_add_rounded),
                label: const LText('Add a device'),
                onPressed: () => openAddDevice(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// This device's QR code and code, plus every way to add a device.
class AddDevicePage extends StatelessWidget {
  const AddDevicePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const LText('Add a device')),
    body: PageWidth(
      maxWidth: 560,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          Space.page,
          Space.sm,
          Space.page,
          Space.xxl + MediaQuery.paddingOf(context).bottom,
        ),
        children: const [PairCard()],
      ),
    ),
  );
}
