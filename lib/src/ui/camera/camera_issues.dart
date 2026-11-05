import 'dart:async';
import 'dart:io';

import 'package:nanit_camera/nanit_camera.dart';

import '../../local_nanit.dart';
import '../../nanit_integration.dart';
import '../../nanit_wifi_setup.dart';
import 'camera_help_content.dart';

/// Maps what the camera code reports onto [CameraIssue]s with a fix.

CameraIssue issueForLocalFault(LocalCameraFault fault) => switch (fault) {
  LocalCameraFault.unreachable => CameraIssue.unreachable,
  LocalCameraFault.differentCamera => CameraIssue.differentCamera,
  LocalCameraFault.notACamera => CameraIssue.notACamera,
  LocalCameraFault.videoDidNotStart => CameraIssue.videoDidNotStart,
  LocalCameraFault.videoInterrupted => CameraIssue.videoInterrupted,
  LocalCameraFault.roomReadings => CameraIssue.roomReadings,
  LocalCameraFault.nightLight => CameraIssue.nightLight,
  LocalCameraFault.savedDetails => CameraIssue.savedDetails,
};

CameraIssue issueForWifiFault(WifiSetupFault fault) => switch (fault) {
  WifiSetupFault.bluetoothOff => CameraIssue.bluetoothOff,
  WifiSetupFault.bluetoothUnavailable => CameraIssue.bluetoothPermission,
  WifiSetupFault.noCameraFound => CameraIssue.bleNoCameraFound,
  WifiSetupFault.notNanit => CameraIssue.notNanit,
  WifiSetupFault.rejected => CameraIssue.wifiRejected,
  WifiSetupFault.interrupted => CameraIssue.wifiInterrupted,
};

/// Why adding a camera by address failed ([LocalNanitHub.add]).
CameraIssue issueForAddError(Object error) => switch (error) {
  FormatException(:final message) when message.contains('IPv4') =>
    CameraIssue.invalidAddress,
  FormatException(:final message) when message.contains('identify') =>
    CameraIssue.notACamera,
  SocketException() || TimeoutException() => CameraIssue.cannotReachAddress,
  _ => CameraIssue.cannotReachAddress,
};

CameraIssue? issueForLiveFailure(NanitLiveFailure? failure) =>
    switch (failure) {
      NanitLiveFailure.streamLimit => CameraIssue.streamLimit,
      NanitLiveFailure.noLanAddress => CameraIssue.noLanAddress,
      NanitLiveFailure.noVideo => CameraIssue.firewall,
      NanitLiveFailure.interrupted => CameraIssue.videoInterrupted,
      // The link's own failure explains it better.
      NanitLiveFailure.notConnected || null => null,
    };

/// The account-mode connection problem, if any.
CameraIssue? issueForAccountLink(NanitHub hub) {
  final c = hub.connection;
  if (c == null || c.state != NanitLinkState.failed) return null;
  return switch (c.failure) {
    NanitLinkFailure.certificate => CameraIssue.identityChanged,
    NanitLinkFailure.unauthorized => CameraIssue.cameraRefused,
    NanitLinkFailure.notSignedIn || null =>
      hub.account.needsSignIn || !hub.signedIn
          ? CameraIssue.tokenExpired
          : CameraIssue.cloudUnreachable,
  };
}

CameraHelpTopic topicFor(CameraIssue issue, {required bool windows}) =>
    cameraHelpTopics(windows: windows).firstWhere((t) => t.id == issue.name);
