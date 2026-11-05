import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../background.dart';
import '../distribution.dart';
import '../store.dart';
import '../sync.dart';
import '../routines.dart';
import '../nanit_integration.dart';
import 'baby_photo.dart';
import 'camera_page.dart';
import 'common.dart';
import 'growth_page.dart';
import 'data_transfer.dart';
import 'disclaimer_page.dart';
import 'hub_page.dart';
import 'peer_page.dart';
import 'pump_lab_page.dart';
import 'pump_page.dart';
import 'qr_sync_page.dart';
import 'sheets.dart';
import 'theme.dart';
import 'language_picker.dart';
import 'update_card.dart';

void openSettings(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const SettingsPage()),
);

String feedIntervalLabel(int m) =>
    m % 60 == 0 ? '${m ~/ 60} h' : '${m ~/ 60} h ${m % 60} m';

String appearanceLabel(String a) => switch (a) {
  'dark' => 'Dark',
  'system' => 'Match phone',
  _ => 'Light',
};

/// Small status pill in the app bar: shows whether the hub's devices are in sync.
/// Tapping it opens the hub view with every device's status.
class SyncChip extends StatelessWidget {
  const SyncChip({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final scheme = context.colors;
    final nest = context.nest;
    final (Color color, String label) = app.peers.isEmpty
        ? (scheme.onSurfaceVariant, 'Share')
        : app.syncing
        ? (scheme.primary, 'Syncing')
        : app.syncPausedForVersion
        ? (nest.warn.color, 'Sync paused')
        : app.syncHasError
        ? (nest.warn.color, 'Not synced')
        : (nest.success.color, app.lastSync == null ? 'Paired' : 'Synced');
    if (compact) {
      return LIconButton(
        tooltip: label,
        icon: Icon(
          app.peers.isEmpty ? Icons.people_alt_rounded : Icons.circle,
          color: color,
          size: app.peers.isEmpty ? 22 : 12,
        ),
        onPressed: () => openHub(context),
      );
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: Space.xs),
      child: ActionChip(
        avatar: Icon(
          app.peers.isEmpty ? Icons.people_alt_rounded : Icons.circle,
          size: app.peers.isEmpty ? 18 : 10,
          color: color,
        ),
        label: LText(label),
        onPressed: () => openHub(context),
      ),
    );
  }
}

/// Light / Dark / Match phone choice (used in Settings and the first-time setup).
class AppearancePicker extends StatelessWidget {
  const AppearancePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Row(
      children: [
        for (final (value, glyph) in [
          ('light', Glyphs.light),
          ('dark', Glyphs.dark),
          ('system', Glyphs.auto),
        ]) ...[
          Expanded(
            child: OptionTile(
              glyph: glyph,
              label: appearanceLabel(value),
              selected: app.appearance == value,
              color: Colors.transparent,
              onTap: () => app.setAppearance(value),
            ),
          ),
          if (value != 'system') const SizedBox(width: Space.sm),
        ],
      ],
    );
  }
}

/// Feed reminder switch and interval (used in Settings and the first-time setup).
/// Notification or alarm, for feed or pill reminders on this phone.
class RingStylePicker extends StatelessWidget {
  const RingStylePicker({
    super.key,
    required this.alarm,
    required this.onChanged,
  });
  final bool alarm;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    // The Play build only has normal notifications.
    if (Distribution.play) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              icon: Icon(Icons.notifications_rounded),
              label: LText('Notification'),
            ),
            ButtonSegment(
              value: true,
              icon: Icon(Icons.alarm_rounded),
              label: LText('Alarm'),
            ),
          ],
          selected: {alarm},
          showSelectedIcon: false,
          onSelectionChanged: (v) => onChanged(v.single),
        ),
        const SizedBox(height: Space.sm),
        LText(
          alarm
              ? 'Rings with your alarm sound until you stop or snooze it, even on silent, and shows on the lock screen.'
              : 'A normal notification with your notification sound.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

Future<void> _showPillRingSheet(BuildContext context) => showSheet(
  context,
  Builder(
    builder: (context) {
      final app = AppScope.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHeader(
            title: 'Pill reminders',
            subtitle: 'How they ring on this phone',
          ),
          if (Distribution.play)
            LText(
              'Pill reminders show as normal notifications.',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            )
          else
            RingStylePicker(
              alarm: app.pillAlarm,
              onChanged: (v) => app.setReminderAlarm(pill: v),
            ),
          const SizedBox(height: Space.sm),
        ],
      );
    },
  ),
);

class FeedReminderOptions extends StatelessWidget {
  const FeedReminderOptions({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final heading = Theme.of(context).textTheme.titleSmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: SwitchListTile(
            secondary: const Icon(Icons.alarm_rounded),
            title: const LText('Remind me to feed'),
            subtitle: const LText('Counted from the start of the last feed'),
            value: app.feedReminderOn,
            onChanged: (v) => app.setFeedReminder(on: v),
          ),
        ),
        const SizedBox(height: Space.xl),
        Semantics(
          header: true,
          child: LText('How long after a feed?', style: heading),
        ),
        const SizedBox(height: Space.sm),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            for (final m in const [90, 120, 150, 180, 210, 240, 300])
              ChoiceChip(
                label: LText(feedIntervalLabel(m)),
                selected: app.feedReminderOn && app.feedReminderMinutes == m,
                onSelected: (_) => app.setFeedReminder(on: true, minutes: m),
              ),
          ],
        ),
        if (!Distribution.play) ...[
          const SizedBox(height: Space.xl),
          Semantics(header: true, child: LText('How it rings', style: heading)),
          const SizedBox(height: Space.sm),
          RingStylePicker(
            alarm: app.feedAlarm,
            onChanged: (v) => app.setReminderAlarm(feed: v),
          ),
        ],
      ],
    );
  }
}

Future<void> showFeedReminderSheet(BuildContext context) => showSheet(
  context,
  Builder(
    builder: (context) {
      final name = AppScope.of(context).babyName;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetHeader(
            title: 'Feed reminder',
            subtitle: name.isEmpty ? null : 'For $name',
          ),
          const FeedReminderOptions(),
          const SizedBox(height: Space.sm),
        ],
      );
    },
  ),
);

Future<void> _showAppearanceSheet(BuildContext context) => showSheet(
  context,
  const Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SheetHeader(title: 'Appearance'),
      AppearancePicker(),
      SizedBox(height: Space.lg),
      NightLightSwitch(),
      SizedBox(height: Space.sm),
    ],
  ),
);

/// Night light: a dimmer, warmer version of the light theme from 6 pm to 6 am.
/// It is not dark mode, so the text says so.
class NightLightSwitch extends StatelessWidget {
  const NightLightSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Card(
      child: SwitchListTile(
        secondary: const Icon(Icons.nightlight_round),
        title: const LText('Night light'),
        subtitle: const LText(
          'Dims the colours from 6 pm to 6 am so the screen is gentle in a dark room.\n'
          'It is a softer light theme, not dark mode. Choose Dark above for dark all day.',
        ),
        isThreeLine: true,
        value: app.nightLight,
        onChanged: app.setNightLight,
      ),
    );
  }
}

/// Supporting text under a settings section.
class _Footer extends StatelessWidget {
  const _Footer(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(Space.xs, Space.sm, Space.xs, 0),
    child: LText(
      text,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: context.colors.onSurfaceVariant),
    ),
  );
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.initialQuery = ''});

  /// Text already in the search box, e.g. when opened from the global search.
  final String initialQuery;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final _search = TextEditingController(text: widget.initialQuery);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(Iterable<String> terms) {
    final words = _search.text.trim().toLowerCase().split(RegExp(r'\s+'));
    final searchable = terms
        .expand((term) => [term, tr(term, language: 'af')])
        .join(' ')
        .toLowerCase();
    return words.every(searchable.contains);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final sections = <Widget>[];
    void addSection(
      String title,
      List<({List<String> terms, Widget child})> entries, {
      Widget? footer,
      bool card = true,
    }) {
      final matches = entries
          .where((entry) => _matches([title, ...entry.terms]))
          .map((entry) => entry.child)
          .toList();
      if (matches.isEmpty) return;
      sections.addAll([
        SectionTitle(title),
        if (card) ListCard(children: matches) else ...matches,
        ?footer,
      ]);
    }

    addSection('Language', [
      (
        terms: ['Language', 'English', 'Afrikaans'],
        child: const Padding(
          padding: EdgeInsets.all(Space.lg),
          child: LanguagePicker(showLabel: false),
        ),
      ),
    ]);
    addSection(
      'Babies',
      [
        for (final baby in app.babies)
          (
            terms: [baby.name, 'Babies', 'Baby profile', 'Photo', 'Birthday'],
            child: _BabyTile(baby: baby),
          ),
        (
          terms: ['Add a baby', 'Another baby', 'Twins'],
          child: _Tile(
            icon: Icons.person_add_alt_1_rounded,
            title: 'Add a baby',
            value: '',
            onTap: () => _addBaby(context, app),
          ),
        ),
      ],
      footer: const _Footer(
        'Tap a baby to change their name, birthday or photo. '
        'The selected baby is the one you see on the other tabs.',
      ),
    );
    addSection(
      'Reminders',
      [
        if (Distribution.play && !app.reminders.exactAllowed)
          (
            terms: ['Allow exact reminders', 'Alarms & reminders'],
            child: _Tile(
              icon: Icons.alarm_on_rounded,
              title: 'Allow exact reminders',
              subtitle: 'Without this, Android can delay reminders by several minutes',
              value: '',
              onTap: () async {
                await app.reminders.openExactAccessSettings();
              },
            ),
          ),
        (
          terms: [
            'Feed reminder',
            'Remind me to feed',
            'How long after a feed?',
            'How it rings',
            'Notification',
            'Alarm',
            app.babyName,
            feedIntervalLabel(app.feedReminderMinutes),
          ],
          child: _Tile(
            icon: Icons.alarm_rounded,
            title: 'Feed reminder',
            subtitle: app.babyName.isEmpty ? null : 'For ${app.babyName}',
            value: app.feedReminderOn
                ? '${feedIntervalLabel(app.feedReminderMinutes)}${app.feedAlarm && !Distribution.play ? ', alarm' : ''}'
                : 'Off',
            onTap: () => showFeedReminderSheet(context),
          ),
        ),
        (
          terms: ['Pill reminders', 'How it rings', 'Notification', 'Alarm'],
          child: _Tile(
            icon: Glyphs.pillIcon,
            title: 'Pill reminders',
            subtitle: 'For you, on this phone',
            value: app.pillAlarm && !Distribution.play
                ? 'Alarm'
                : 'Notification',
            onTap: () => _showPillRingSheet(context),
          ),
        ),
      ],
      footer: _Footer(
        app.babies.length > 1
            ? 'The feed reminder is kept for each baby: it follows the selected baby. '
                  'Which pills remind you, and when, is set per pill on the Pills tab.'
            : 'Which pills remind you, and when, is set per pill on the Pills tab.',
      ),
    );
    addSection('Appearance', [
      (
        terms: ['Theme', 'Light', 'Dark', 'Match phone'],
        child: _Tile(
          icon: Baby.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
          title: 'Theme',
          value: appearanceLabel(app.appearance),
          onTap: () => _showAppearanceSheet(context),
        ),
      ),
      (
        terms: [
          'Night light',
          'Nighttime',
          'Dim',
          'Dims the colours from 6 pm to 6 am so the screen is gentle in a dark room.',
        ],
        child: SwitchListTile(
          secondary: const Icon(Icons.nightlight_round),
          title: const LText('Night light'),
          subtitle: const LText(
            'Dims the colours from 6 pm to 6 am so the screen is gentle in a dark room.',
          ),
          value: app.nightLight,
          onChanged: app.setNightLight,
        ),
      ),
    ]);
    addSection('Pumping', [
      (
        terms: ['Show Pump on Today', 'Pumping', 'Breast pump', 'Expressing'],
        child: SwitchListTile(
          secondary: const Icon(Icons.water_drop_rounded),
          title: const LText('Show Pump on Today'),
          subtitle: const LText(
            'A Pump button next to Feed and Nappy, for logging pumping and '
            'controlling Momcozy pumps.',
          ),
          value: app.pumpOnToday,
          onChanged: app.setShowPump,
        ),
      ),
      (
        terms: ['Pumping', 'Momcozy', 'BP380', 'Bluetooth', 'Your pumps'],
        child: _Tile(
          icon: Icons.bluetooth_rounded,
          title: 'Pumping',
          subtitle: Platform.isAndroid
              ? 'Your pumps, sessions and stats'
              : 'Sessions and stats',
          value: app.pumpDevices.isEmpty ? '' : '${app.pumpDevices.length}',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PumpPage()),
          ),
        ),
      ),
      if (Platform.isAndroid)
        (
          terms: ['Pump lab', 'Diagnostics', 'Packet log'],
          child: _Tile(
            icon: Icons.science_outlined,
            title: 'Pump lab',
            subtitle: 'Diagnostics and raw pump data',
            value: '',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PumpLabPage()),
            ),
          ),
        ),
    ]);
    addSection('Camera', [
      (
        terms: ['Show Camera on Today', 'Camera', 'Nanit'],
        child: SwitchListTile(
          secondary: const Icon(Icons.videocam_rounded),
          title: const LText('Show Camera on Today'),
          subtitle: const LText(
            'A Camera button on Today, for watching the Nanit camera.',
          ),
          value: app.cameraOnToday,
          onChanged: app.setShowCamera,
        ),
      ),
      (
        terms: ['Camera', 'Nanit', 'Baby monitor', 'Video', 'Sound', 'Motion'],
        child: ListenableBuilder(
          listenable: NanitHub.instance,
          builder: (context, _) {
            final hub = NanitHub.instance;
            return _Tile(
              icon: Icons.videocam_rounded,
              title: 'Nanit camera',
              subtitle: hub.local.saved != null
                  ? 'Video, audio and room readings over your home network'
                  : hub.paired
                  ? 'Live view, room and alerts'
                  : 'Watch your Nanit camera over home Wi-Fi',
              value: hub.hasCamera
                  ? hub.cameraName
                  : hub.signedIn
                  ? 'Pick a camera'
                  : '',
              onTap: () => openCamera(context),
            );
          },
        ),
      ),
    ]);
    addSection('Family hub', [
      (
        terms: [
          'Family hub',
          'Devices sharing this log',
          'Add a device',
          'Sync details',
          'This device',
          'Everyone in the hub sees the same log',
          'Pair',
          'Share',
          'Scan code',
          'Type code',
          'Address',
          'Code',
          'Wi-Fi',
          'Sync by QR code',
          for (final peer in app.peers) ...[peer.name, peer.host],
        ],
        child: const HubSummary(),
      ),
      (
        terms: [
          'Sync now',
          'Sync automatically',
          'Keep syncing when closed',
          'Allow background use',
          'After every change and every minute',
        ],
        child: const Padding(
          padding: EdgeInsets.only(top: Space.lg),
          child: _PeersCard(),
        ),
      ),
    ], card: false);
    addSection(
      'Your data',
      [
        (
          terms: ['Export backup', 'History', 'spreadsheet'],
          child: _Tile(
            icon: Icons.save_alt_rounded,
            title: 'Export backup',
            value: '',
            onTap: () => exportBackupFile(context),
          ),
        ),
        (
          terms: ['Import backup', 'Your saved data could not be read'],
          child: _Tile(
            icon: Icons.upload_file_rounded,
            title: 'Import backup',
            value: '',
            onTap: () => importBackupFile(context),
          ),
        ),
      ],
      footer: const _Footer(
        'Importing adds to your log and never deletes anything. '
        'A spreadsheet export is on the History tab.',
      ),
    );
    addSection('This device', [
      (
        terms: ['Device name', app.deviceName],
        child: _Tile(
          icon: Platform.isAndroid
              ? Icons.phone_android_rounded
              : Icons.computer_rounded,
          title: 'Device name',
          value: app.deviceName,
          subtitle: app.deviceNameCustom
              ? 'A name you chose'
              : 'Set by this device',
          onTap: () => _editDeviceName(context, app),
        ),
      ),
      (
        terms: [
          'App version',
          AppState.appVersion,
          'Check for updates',
          'Update',
          'GitHub',
        ],
        child: _Tile(
          icon: Icons.info_outline_rounded,
          title: 'App version',
          value: AppState.appVersion,
          onTap: () => showAppUpdates(context),
        ),
      ),
      (
        terms: [
          'Disclaimer & responsibility',
          'About',
          'Legal',
          'Use at your own risk',
        ],
        child: _Tile(
          icon: Icons.description_outlined,
          title: 'Disclaimer & responsibility',
          value: '',
          subtitle: 'Applies to all features',
          onTap: () => showDisclaimer(context),
        ),
      ),
      (
        terms: ['Run first-time setup again', 'Welcome'],
        child: _Tile(
          icon: Icons.restart_alt_rounded,
          title: 'Run first-time setup again',
          value: '',
          onTap: () {
            Navigator.popUntil(context, (r) => r.isFirst);
            app.restartSetup();
          },
        ),
      ),
    ]);
    return Scaffold(
      appBar: AppBar(title: const LText('Settings')),
      body: PageWidth(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.page,
                Space.sm,
                Space.page,
                0,
              ),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: LInputDecoration(
                  labelText: 'Search settings',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : LIconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(_search.clear),
                        ),
                ),
              ),
            ),
            Expanded(
              child: PullToSync(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  physics: const AlwaysScrollableScrollPhysics(),
                  // Room for the phone's navigation buttons (e.g. Samsung) below the last item.
                  padding: EdgeInsets.fromLTRB(
                    Space.page,
                    0,
                    Space.page,
                    Space.xxl + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    if (app.loadProblem != null)
                      Padding(
                        padding: const EdgeInsets.only(top: Space.lg),
                        child: Card(
                          child: ListTile(
                            leading: Icon(
                              Icons.warning_amber_rounded,
                              color: context.colors.error,
                            ),
                            title: const LText(
                              'Your saved data could not be read',
                            ),
                            subtitle: LText(
                              'A copy was kept. Use Import backup and choose:\n${app.loadProblem}',
                            ),
                          ),
                        ),
                      ),
                    if (_search.text.trim().isEmpty) const _Summary(),
                    ...sections,
                    if (sections.isEmpty)
                      const EmptyState(
                        icon: Icons.search_off_rounded,
                        text: 'No settings found. Try a different search.',
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.subtitle,
  });
  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: LText(title),
    subtitle: subtitle == null ? null : LText(subtitle!),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: LText(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: context.colors.onSurfaceVariant),
            ),
          ),
        const SizedBox(width: Space.xs),
        const Icon(Icons.chevron_right_rounded),
      ],
    ),
    onTap: onTap,
  );
}

/// Friendly summary at the top: baby, this device and how syncing is going.
class _Summary extends StatelessWidget {
  const _Summary();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final status = app.peers.isEmpty
        ? 'Not paired yet'
        : app.syncing
        ? 'Syncing'
        : app.syncPausedForVersion
        ? 'Sync paused'
        : app.syncHasError
        ? 'Not synced'
        : app.lastSync == null
        ? 'Paired'
        : 'Synced ${ago(app.lastSync!)}';
    final ok =
        app.peers.isNotEmpty && !app.syncPausedForVersion && !app.syncHasError;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: Space.lg),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Row(
            children: [
              Semantics(
                button: true,
                label: tr('Change photo'),
                child: Tooltip(
                  message: tr('Change photo'),
                  child: InkResponse(
                    radius: 40,
                    onTap: () async {
                      final photo = await pickBabyPhoto(context);
                      if (photo == null || !context.mounted) return;
                      app.saveBabyProfile(
                        name: app.activeBaby.name,
                        dateOfBirth: app.activeBaby.dateOfBirth,
                        photo: photo,
                      );
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        BabyPhoto(photo: app.activeBaby.photo, size: 56),
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.nest.card,
                                width: 2,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(Space.xs),
                              child: Icon(
                                Icons.photo_camera_rounded,
                                size: 12,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(Corners.sm),
                      onTap: () => editBabyProfile(context),
                      child: Row(
                        children: [
                          Flexible(
                            child: LText.raw(
                              app.babyName.isEmpty
                                  ? tr('Nestling')
                                  : app.babyName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleLarge,
                            ),
                          ),
                          const SizedBox(width: Space.sm),
                          Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: scheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    LText(
                      app.deviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Space.xs),
                    Row(
                      children: [
                        Icon(
                          ok ? Icons.check_circle_rounded : Icons.circle,
                          size: ok ? 16 : 10,
                          color: ok
                              ? context.nest.success.color
                              : app.peers.isEmpty
                              ? scheme.onSurfaceVariant
                              : context.nest.warn.color,
                        ),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: LText(
                            status,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Device name: starts as the device's own name; typing replaces it, and a
/// button goes back to the device's own name.
Future<void> _editDeviceName(BuildContext context, AppState app) async {
  final c = TextEditingController(text: app.deviceName);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const LText('Device name'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: c,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const LInputDecoration(
              hintText: 'Type a name your partner will recognise',
            ),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          if (app.deviceNameCustom) ...[
            const SizedBox(height: Space.sm),
            TextButton.icon(
              icon: const Icon(Icons.restart_alt_rounded),
              label: const LText("Use this device's own name"),
              onPressed: () => Navigator.pop(ctx, ''),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const LText('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, c.text),
          child: const LText('Save'),
        ),
      ],
    ),
  );
  if (result == null) return;
  if (result.trim().isEmpty) {
    await app.useDeviceOwnName();
  } else if (result.trim() != app.deviceName) {
    app.setDeviceName(result.trim());
  }
}

/// One baby in the Babies list: photo, name, age. Tap to edit the profile; the
/// trailing control shows or picks which baby the app is following.
class _BabyTile extends StatelessWidget {
  const _BabyTile({required this.baby});
  final BabyProfile baby;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final active = baby.id == app.activeBabyId;
    final scheme = context.colors;
    return ListTile(
      leading: BabyPhoto(photo: baby.photo, size: 40),
      title: LText.raw(
        baby.name.isEmpty ? tr('Baby') : baby.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: LText.raw(
        '${babyAge(baby)}${active ? ' · ${tr('Selected')}' : ''}',
      ),
      trailing: active
          ? Icon(Icons.check_circle_rounded, color: scheme.primary)
          : TextButton(
              onPressed: () {
                if (!app.selectBaby(baby.id)) {
                  showMessage(
                    context,
                    'Save or stop the feed timer before switching babies.',
                  );
                }
              },
              child: const LText('Select'),
            ),
      onTap: () => editBabyProfile(context, baby),
    );
  }
}

Future<void> _addBaby(BuildContext context, AppState app) async {
  final name = await _ask(context, 'Add a baby', '', 'e.g. Emma');
  if (name == null || name.trim().isEmpty) return;
  app.addBaby(name);
}

Future<String?> _ask(
  BuildContext context,
  String title,
  String value,
  String hint,
) {
  final c = TextEditingController(text: value);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: LText(title),
      content: TextField(
        controller: c,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: LInputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const LText('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, c.text),
          child: const LText('Save'),
        ),
      ],
    ),
  );
}

/// This device's QR code and code, plus the buttons to connect to the other device.
class PairCard extends StatelessWidget {
  const PairCard({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final ip = app.ips.isEmpty ? null : app.ips.first;
    final port = app.server.port;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LText(
              'Everyone in the hub keeps the same log over your home Wi‑Fi. '
              'On the device you are adding, open Settings and scan this code. '
              'Add a device once and it shares with everyone else automatically.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Space.lg),
            if (ip == null || port == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.lg),
                child: LText(
                  port == null
                      ? 'Sync could not start on this device.'
                      : 'Connect to Wi‑Fi to pair.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              )
            else ...[
              // Always dark on white so it scans well in dark mode too.
              Center(
                child: Container(
                  padding: const EdgeInsets.all(Space.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(Corners.lg),
                  ),
                  child: QrImageView(
                    data: PairInfo(ip, port, app.syncKey).toUri(),
                    size: 180,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.circle,
                      color: Color(0xFF1A1D21),
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.circle,
                      color: Color(0xFF1A1D21),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Space.lg),
              Row(
                children: [
                  Expanded(
                    child: _Big(
                      label: 'ADDRESS',
                      value: port == defaultSyncPort ? ip : '$ip:$port',
                    ),
                  ),
                  Expanded(
                    child: _Big(
                      label: 'CODE',
                      value:
                          '${app.syncKey.substring(0, 3)} ${app.syncKey.substring(3)}',
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: Space.lg),
            const Divider(),
            const SizedBox(height: Space.lg),
            Semantics(
              header: true,
              child: LText('Add a device', style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: Space.md),
            Row(
              children: [
                if (Platform.isAndroid || Platform.isIOS) ...[
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const LText('Scan code'),
                      onPressed: () async {
                        final info = await Navigator.push<PairInfo>(
                          context,
                          MaterialPageRoute(builder: (_) => const _ScanPage()),
                        );
                        if (info != null && context.mounted) {
                          await _pair(
                            context,
                            app,
                            info.host,
                            info.port,
                            info.key,
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: Space.sm),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.keyboard_rounded),
                    label: const LText('Type code'),
                    onPressed: () => _typeCode(context, app),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            TextButton.icon(
              icon: const Icon(Icons.qr_code_2_rounded),
              label: const LText('Not on the same Wi-Fi? Sync by QR code'),
              onPressed: () => openQrSync(
                context,
                peer: app.peers.length == 1 ? app.peers.first : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _typeCode(BuildContext context, AppState app) async {
    // Pre-fill our own network prefix so usually only the last number is typed.
    final own = app.ips.isEmpty ? '' : app.ips.first;
    final address = TextEditingController(
      text: own.isEmpty ? '' : own.substring(0, own.lastIndexOf('.') + 1),
    );
    final code = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const LText('Add a device'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LText(
              'Type the address and code shown on the other device (Settings, Family hub).',
            ),
            const SizedBox(height: Space.lg),
            TextField(
              controller: address,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const LInputDecoration(labelText: 'Address'),
            ),
            const SizedBox(height: Space.md),
            TextField(
              controller: code,
              keyboardType: TextInputType.number,
              decoration: const LInputDecoration(labelText: 'Code'),
              onSubmitted: (_) => Navigator.pop(ctx, true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const LText('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const LText('Connect'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final parts = address.text.trim().split(':');
    final port = parts.length > 1
        ? int.tryParse(parts[1]) ?? defaultSyncPort
        : defaultSyncPort;
    await _pair(
      context,
      app,
      parts[0],
      port,
      code.text.replaceAll(RegExp(r'\D'), ''),
    );
  }

  Future<void> _pair(
    BuildContext context,
    AppState app,
    String host,
    int port,
    String key,
  ) async {
    String message;
    try {
      await app.pair(host, port, key);
      message = 'Device added and synced';
    } on VersionMismatchException catch (e) {
      // Paired, but the versions differ: let the user decide.
      final peer = app.peers.where((p) => p.deviceId == e.deviceId).firstOrNull;
      if (peer == null || !context.mounted) return;
      if (!await confirmVersionMismatch(context, peer)) {
        message =
            'Paired. Syncing waits until both phones have the same version';
      } else {
        try {
          await app.acceptVersion(peer);
          message = 'Device added and synced';
        } catch (e) {
          message = 'Could not sync: $e';
        }
      }
    } catch (e) {
      message = 'Could not connect: $e';
    }
    if (context.mounted) showMessage(context, message);
  }
}

/// Sync options for the hub.
class _PeersCard extends StatelessWidget {
  const _PeersCard();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ListCard(
      children: [
        if (app.peers.isNotEmpty)
          ListTile(
            leading: const Icon(Icons.sync_rounded),
            title: const LText('Sync now'),
            trailing: app.syncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: app.syncing
                ? null
                : () async {
                    final error = await app.syncAll();
                    if (context.mounted) {
                      showMessage(context, error ?? 'Synced');
                    }
                  },
          ),
        SwitchListTile(
          secondary: const Icon(Icons.autorenew_rounded),
          title: const LText('Sync automatically'),
          subtitle: const LText('After every change and every minute'),
          value: app.autoSync,
          onChanged: app.setAutoSync,
        ),
        if (BackgroundSync.supported)
          SwitchListTile(
            secondary: const Icon(Icons.cloud_sync_rounded),
            title: const LText('Keep syncing when closed'),
            subtitle: const LText('Shows a quiet notification while on'),
            value: app.backgroundSync,
            onChanged: app.setBackgroundSync,
          ),
        if (BackgroundSync.batteryExemptSupported &&
            app.backgroundSync &&
            !app.batteryExempt)
          ListTile(
            leading: Icon(
              Icons.battery_alert_rounded,
              color: context.nest.warn.color,
            ),
            title: const LText('Allow background use'),
            subtitle: const LText(
              'Otherwise Android may pause syncing while the screen is off',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: app.requestBatteryExempt,
          ),
      ],
    );
  }
}

class _Big extends StatelessWidget {
  const _Big({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        LText(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Space.xs),
        SelectableText(
          value,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _ScanPage extends StatefulWidget {
  const _ScanPage();

  @override
  State<_ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<_ScanPage> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const LText('Scan the other device\'s code')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_done) return;
          for (final b in capture.barcodes) {
            final info = PairInfo.parse(b.rawValue ?? '');
            if (info != null) {
              _done = true;
              Navigator.pop(context, info);
              return;
            }
          }
        },
      ),
    );
  }
}
