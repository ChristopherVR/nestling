import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nanit_camera/nanit_camera.dart';

import 'background.dart';
import 'localization.dart';

/// Nestling's side of the nanit_camera package: one shared camera
/// ([NanitHub]), the words (through [tr]) and the notification ids and
/// channel. The protocol lives in the package.
///
/// Delivery goes through the same notifications plugin as [Reminders], which
/// must have been initialised first (AppState does that on start). This
/// never initialises the plugin itself: a second initialize() would replace
/// the reminders' tap and snooze handlers.
///
/// Background: alerts arrive while the camera socket is alive. On Android
/// the Dart side keeps running only as long as SyncService (the foreground
/// service) holds the process; the camera socket is not yet tied to that
/// service, so alerts stop when Android kills the app.

/// Notification ids 3000000+ are the camera's; see the id table in
/// notifications.dart. One id per kind, so a new alert replaces the last.
const nanitAlertIdBase = 3000000;

/// The signed-in Nanit account and, once a camera is picked, its control
/// socket, readings, video and alerts. One for the whole app, like
/// [PumpHub].
class NanitHub extends ChangeNotifier {
  static final instance = NanitHub();

  NanitHub({NanitAccount? account, this.alertSink})
    : account = account ?? NanitAccount();

  final NanitAccount account;
  final NanitAlertSink? alertSink;

  NanitCameraConnection? connection;
  NanitCameraClient? client;
  NanitLiveStream? live;
  NanitAlertNotifier? alerts;

  bool loaded = false;
  Future<void>? _loading;

  bool get signedIn => account.signedIn;
  bool get paired => account.paired;

  /// Loads the saved account and, if a camera is paired, connects. Safe to
  /// call more than once.
  Future<void> start() => _loading ??= _start();

  Future<void> _start() async {
    try {
      await account.load();
    } catch (e) {
      // Secure storage unavailable (e.g. in tests): behave as signed out.
      debugPrint('Nanit: could not load the account: $e');
    }
    loaded = true;
    account.addListener(notifyListeners);
    if (account.paired) _open();
    notifyListeners();
    unawaited(account.refreshIfDue());
  }

  void _open() {
    if (connection != null) return;
    final c = connection = NanitCameraConnection(
      account: account,
      locator: _MulticastLocator(),
    );
    c.addListener(notifyListeners);
    final cl = client = NanitCameraClient(c, store: account.store)
      ..addListener(notifyListeners);
    live = NanitLiveStream(client: cl);
    final a = alerts = NanitAlertNotifier(
      events: cl.events,
      account: account,
      store: account.store,
      sink: alertSink ?? NestlingNanitAlertSink(),
    )..addListener(notifyListeners);
    unawaited(a.load());
    c.connect();
  }

  Future<void> _close() async {
    final a = alerts, l = live, cl = client, c = connection;
    alerts = null;
    live = null;
    client = null;
    connection = null;
    a?.dispose();
    l?.dispose();
    cl?.dispose();
    if (c != null) {
      c.removeListener(notifyListeners);
      await c.disconnect();
      c.dispose();
    }
    notifyListeners();
  }

  Future<void> signIn(
    String email,
    String password, {
    required NanitMfaPrompt onMfa,
  }) => account.signIn(email.trim(), password, onMfa: onMfa);

  Future<List<NanitBaby>> babies() => account.babies();

  Future<void> pair(NanitBaby baby) async {
    await _close();
    await account.pair(baby);
    _open();
  }

  /// Retries after a failure (e.g. the camera was off).
  void reconnect() => connection?.connect();

  /// An address typed in by hand, for when the camera is not found.
  Future<void> setManualIp(String? ip) async {
    final v = ip?.trim();
    await account.updatePairing(
      (p) => v == null || v.isEmpty
          ? p.copyWith(clearManualIp: true)
          : p.copyWith(manualIp: v),
    );
    reconnect();
  }

  /// Forgets the camera (and its trusted certificate) but stays signed in,
  /// so it can be picked again, e.g. after a factory reset.
  Future<void> forgetCamera() async {
    await _close();
    await account.unpair();
  }

  Future<void> signOut() async {
    await _close();
    await account.signOut();
  }

  /// Why the camera cannot be reached, in words for the screen, or null.
  String? get problem {
    final c = connection;
    if (c == null) return null;
    if (c.state == NanitLinkState.failed) {
      return switch (c.failure) {
        NanitLinkFailure.certificate =>
          'The camera’s identity changed (was it reset?). Pick it again.',
        NanitLinkFailure.unauthorized =>
          'The camera refused this device. Sign in again.',
        NanitLinkFailure.notSignedIn || null =>
          account.needsSignIn
              ? 'Signed out of Nanit. Sign in again.'
              : 'Could not get a camera key from Nanit. Check the internet.',
      };
    }
    if (c.state == NanitLinkState.waitingToRetry) {
      return 'Looking for the camera on this Wi-Fi…';
    }
    return null;
  }
}

/// mDNS with Android's multicast lock held while it looks.
class _MulticastLocator implements NanitCameraLocator {
  final _mdns = MdnsNanitLocator();
  @override
  Future<String?> locate(String cameraUid) =>
      BackgroundSync.withMulticast(() => _mdns.locate(cameraUid));
}

String nanitAlertTitle(NanitAlert alert) {
  final what = switch (alert.kind) {
    NanitAlertKind.sound => 'sound detected',
    NanitAlertKind.motion => 'motion detected',
  };
  if (alert.babyName.isEmpty) {
    return tr(
      alert.kind == NanitAlertKind.sound ? 'Sound detected' : 'Motion detected',
    );
  }
  return tr('${alert.babyName}: $what');
}

String nanitAlertBody(NanitAlert alert) => tr(
  alert.kind == NanitAlertKind.sound
      ? 'Heard by the Nanit camera'
      : 'Seen by the Nanit camera',
);

/// For NanitCameraView's `label`.
String nanitVideoLabel(NanitVideoLabel label) =>
    tr(englishNanitVideoLabel(label));

/// Shows camera alerts as Nestling notifications.
class NestlingNanitAlertSink implements NanitAlertSink {
  final FlutterLocalNotificationsPlugin _plugin;
  NestlingNanitAlertSink([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  @override
  Future<void> show(NanitAlert alert) => _plugin.show(
    id: nanitAlertIdBase + alert.kind.index,
    title: nanitAlertTitle(alert),
    body: nanitAlertBody(alert),
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        'nanit_alerts',
        'Camera alerts',
        channelDescription: tr('Sound and motion alerts from the Nanit camera'),
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.event,
        timeoutAfter: 10 * 60 * 1000,
      ),
      windows: const WindowsNotificationDetails(),
    ),
  );
}
