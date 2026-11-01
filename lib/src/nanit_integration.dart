import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nanit_camera/nanit_camera.dart';

import 'localization.dart';

/// Nestling's side of the nanit_camera package: the words (through [tr]) and
/// the notification ids and channel. Everything else about the camera lives
/// in the package.
///
/// Delivery goes through the same notifications plugin as [Reminders], which
/// must have been initialised first (AppState does that on start). This
/// never initialises the plugin itself: a second initialize() would replace
/// the reminders' tap and snooze handlers.
///
/// Background: the plugin shows notifications from any isolate that is
/// alive. While Nestling is in the background on Android the Dart side keeps
/// running only as long as SyncService (the foreground service) holds the
/// process; the camera socket is not yet tied to that service, so alerts
/// stop when Android kills the app.

/// Notification ids 3000000+ are the camera's; see the id table in
/// notifications.dart. One id per kind, so a new alert replaces the last.
const nanitAlertIdBase = 3000000;

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

String nanitAlertBody(NanitAlert alert) => alert.provisional
    ? tr('Experimental: this alert type is not verified yet')
    : tr(
        alert.kind == NanitAlertKind.sound
            ? 'Heard by the Nanit camera'
            : 'Seen by the Nanit camera',
      );

/// For NanitCameraView's `label`.
String nanitVideoLabel(NanitVideoLabel label) => tr(switch (label) {
  NanitVideoLabel.paused => 'Camera paused',
  NanitVideoLabel.showCamera => 'Show camera',
  NanitVideoLabel.connecting => 'Connecting…',
  NanitVideoLabel.tryAgain => 'Try again',
  NanitVideoLabel.noOffer => 'The camera did not send video',
  NanitVideoLabel.notConnected => 'Not connected to the camera',
  NanitVideoLabel.couldNotConnect => 'Could not connect to the video',
  NanitVideoLabel.interrupted => 'Video connection interrupted',
});

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
