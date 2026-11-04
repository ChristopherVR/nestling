import 'package:flutter/material.dart';
import 'package:nanit_camera/nanit_camera.dart';

import '../nanit_integration.dart';
import 'common.dart';
import 'theme.dart';
import 'local_camera_page.dart';

void openCamera(BuildContext context) => Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const CameraPage()),
);

/// Local camera setup and viewing, with optional legacy account connectivity.
class CameraPage extends StatefulWidget {
  const CameraPage({super.key, this.hub});

  /// Injected for tests; the app's shared [NanitHub] otherwise.
  final NanitHub? hub;

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  NanitHub get hub => widget.hub ?? NanitHub.instance;
  bool _accountMode = false;

  @override
  void initState() {
    super.initState();
    hub.start();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: hub,
    builder: (context, _) {
      final Widget body;
      if (!hub.loaded) {
        body = const Center(child: CircularProgressIndicator());
      } else if (hub.local.saved != null) {
        body = LocalCameraWatch(
          hub: hub.local,
          onWifiSetup: () async {
            if (!context.mounted) return;
            await Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (context) => Scaffold(
                  appBar: AppBar(title: const LText('Camera Wi-Fi')),
                  body: PageWidth(
                    maxWidth: 720,
                    child: LocalCameraSetup(
                      hub: hub,
                      setupWifi: true,
                      onAccount: () => Navigator.pop(context),
                      onConnected: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      } else if (!_accountMode && !hub.paired) {
        body = LocalCameraSetup(
          hub: hub,
          onAccount: () => setState(() => _accountMode = true),
        );
      } else if (!hub.signedIn && !hub.paired) {
        body = _SignIn(hub: hub);
      } else if (!hub.paired) {
        body = _PickCamera(hub: hub);
      } else {
        body = _Watch(hub: hub);
      }
      return Scaffold(
        appBar: AppBar(
          title: const LText('Camera'),
          actions: [
            if (_accountMode || (hub.paired && hub.local.saved == null))
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => Scaffold(
                      appBar: AppBar(title: const LText('Local camera')),
                      body: PageWidth(
                        maxWidth: 720,
                        child: LocalCameraSetup(
                          hub: hub,
                          onAccount: () => Navigator.pop(context),
                          onConnected: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const LText('Local setup'),
              ),
          ],
        ),
        body: PageWidth(maxWidth: 720, child: body),
      );
    },
  );
}

// --- Sign in ------------------------------------------------------------------

class _SignIn extends StatefulWidget {
  const _SignIn({required this.hub});
  final NanitHub hub;

  @override
  State<_SignIn> createState() => _SignInState();
}

class _SignInState extends State<_SignIn> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Enter your Nanit email and password');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.hub.signIn(
        _email.text,
        _password.text,
        onMfa: (c) => _askCode(context, c),
      );
    } on NanitAuthException catch (e) {
      if (mounted) setState(() => _error = _authMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: _pagePadding(context),
    children: [
      const SizedBox(height: 8),
      _Intro(
        icon: Icons.videocam_rounded,
        title: 'Watch your Nanit camera',
        text:
            'Sign in with your Nanit account once. After that, Nestling talks '
            'to the camera over your home Wi-Fi, even when the internet is '
            'down.',
      ),
      const SizedBox(height: 16),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _email,
                  enabled: !_busy,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const LInputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  enabled: !_busy,
                  obscureText: _hide,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _go(),
                  decoration: LInputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _hide
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                      ),
                      onPressed: () => setState(() => _hide = !_hide),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  LText(
                    _error!,
                    style: TextStyle(
                      color: Baby.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _go,
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const LText('Sign in to Nanit'),
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      LText(
        'Your password goes only to Nanit. This device keeps the sign-in '
        'key in its secure storage.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Baby.muted, fontWeight: FontWeight.w600),
      ),
    ],
  );
}

Future<String?> _askCode(BuildContext context, NanitMfaChallenge c) async {
  if (!context.mounted) return null;
  return showDialog<String>(
    context: context,
    builder: (_) => _CodeDialog(challenge: c),
  );
}

/// Owns its text controller, so nothing is disposed while the dialog is
/// still animating out.
class _CodeDialog extends StatefulWidget {
  const _CodeDialog({required this.challenge});
  final NanitMfaChallenge challenge;

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    try {
      await widget.challenge.resend();
      if (mounted) showMessage(context, 'Code sent again');
    } catch (_) {
      if (mounted) showMessage(context, 'Could not send the code again');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge;
    final where = c.channel == 'email' ? 'email' : 'phone';
    final hint = c.suffix.isEmpty ? '' : ' (…${c.suffix})';
    return AlertDialog(
      title: const LText('Enter the code'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LText(
            c.attempt > 1
                ? 'That code did not work. Try the newest one.'
                : 'Nanit sent a code to your $where$hint.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            onSubmitted: (v) => Navigator.pop(context, v),
            decoration: const LInputDecoration(labelText: 'Code'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _resend, child: const LText('Send again')),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const LText('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _code.text),
          child: const LText('Continue'),
        ),
      ],
    );
  }
}

String _authMessage(NanitAuthException e) => switch (e.reason) {
  NanitAuthFailure.rejected => 'Nanit did not accept that email and password',
  NanitAuthFailure.mfaCancelled => 'Sign-in cancelled',
  NanitAuthFailure.mfaRejected => 'The code was not accepted',
  NanitAuthFailure.offline => 'Could not reach Nanit. Check the internet.',
  NanitAuthFailure.sessionExpired => 'Signed out of Nanit. Sign in again.',
  NanitAuthFailure.notPaired => 'That baby has no camera',
  NanitAuthFailure.unexpectedResponse => 'Nanit answered unexpectedly',
};

// --- Pick a camera ------------------------------------------------------------

class _PickCamera extends StatefulWidget {
  const _PickCamera({required this.hub});
  final NanitHub hub;

  @override
  State<_PickCamera> createState() => _PickCameraState();
}

class _PickCameraState extends State<_PickCamera> {
  late Future<List<NanitBaby>> _babies = widget.hub.babies();
  String? _pairing;

  Future<void> _pick(NanitBaby b) async {
    setState(() => _pairing = b.uid);
    try {
      await widget.hub.pair(b);
    } on NanitAuthException catch (e) {
      if (mounted) showMessage(context, _authMessage(e));
    } finally {
      if (mounted) setState(() => _pairing = null);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: _pagePadding(context),
    children: [
      const SizedBox(height: 8),
      const _Intro(
        icon: Icons.child_care_rounded,
        title: 'Which camera?',
        text: 'Pick the baby whose camera this device should watch.',
      ),
      const SizedBox(height: 8),
      FutureBuilder(
        future: _babies,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasError) {
            final e = snap.error;
            return _Problem(
              text: e is NanitAuthException
                  ? _authMessage(e)
                  : 'Could not load your cameras',
              action: 'Try again',
              onAction: () => setState(() => _babies = widget.hub.babies()),
            );
          }
          final babies = snap.data!;
          if (babies.isEmpty) {
            return const _Problem(text: 'This Nanit account has no babies');
          }
          return ListCard(
            children: [
              for (final b in babies)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  enabled: b.cameraUid != null && _pairing == null,
                  leading: IconBubble(
                    glyph: (s, c) =>
                        Icon(Icons.videocam_rounded, size: s, color: c),
                    color: Baby.primarySoft,
                    iconColor: Baby.primary,
                    size: 40,
                  ),
                  title: LText.raw(
                    b.name.isEmpty ? '—' : b.name,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: LText(
                    b.cameraUid == null ? 'No camera' : 'Nanit camera',
                  ),
                  trailing: _pairing == b.uid
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.chevron_right_rounded, color: Baby.muted),
                  onTap: () => _pick(b),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 12),
      Center(
        child: TextButton(
          onPressed: widget.hub.signOut,
          child: const LText('Sign out of Nanit'),
        ),
      ),
    ],
  );
}

// --- Watch --------------------------------------------------------------------

class _Watch extends StatelessWidget {
  const _Watch({required this.hub});
  final NanitHub hub;

  @override
  Widget build(BuildContext context) {
    final live = hub.live;
    final client = hub.client;
    final problem = hub.problem;
    final failed = hub.connection?.state == NanitLinkState.failed;
    return ListView(
      padding: _pagePadding(context),
      children: [
        const SizedBox(height: 8),
        if (live != null) NanitCameraView(stream: live, label: nanitVideoLabel),
        if (problem != null) ...[
          const SizedBox(height: 12),
          _Problem(
            text: problem,
            action: failed
                ? _fixLabel(hub)
                : hub.account.pairing?.manualIp == null
                ? 'Enter address'
                : null,
            onAction: failed
                ? () => _fix(context, hub)
                : () => editCameraAddress(context, hub),
          ),
        ],
        if (client != null)
          NanitCameraControls(
            client: client,
            alerts: hub.alerts,
            text: tr,
            ago: ago,
            header: (_, title) => SectionTitle(title),
          ),
        const SectionTitle('Camera'),
        _Details(hub: hub),
      ],
    );
  }

  static String _fixLabel(NanitHub hub) => switch (hub.connection?.failure) {
    NanitLinkFailure.certificate => 'Pick the camera again',
    NanitLinkFailure.unauthorized ||
    NanitLinkFailure.notSignedIn ||
    null => hub.signedIn ? 'Try again' : 'Sign in again',
  };

  static Future<void> _fix(BuildContext context, NanitHub hub) async {
    switch (hub.connection?.failure) {
      case NanitLinkFailure.certificate:
        await hub.forgetCamera();
      case _ when !hub.signedIn:
        await hub.signOut();
      case _:
        hub.reconnect();
    }
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.hub});
  final NanitHub hub;

  @override
  Widget build(BuildContext context) {
    final p = hub.account.pairing;
    final c = hub.connection;
    final firmware = hub.client?.status?.currentVersion;
    final status = switch (c?.state) {
      NanitLinkState.connected => 'Connected at ${c!.address}',
      NanitLinkState.connecting => 'Connecting…',
      NanitLinkState.waitingToRetry => 'Looking for the camera…',
      NanitLinkState.failed => 'Not connected',
      NanitLinkState.idle || null => 'Not connected',
    };
    final expires = hub.account.cameraTokenExpires;
    TextStyle sub() =>
        TextStyle(color: Baby.muted, fontWeight: FontWeight.w600);
    return ListCard(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          title: LText.raw(
            p?.babyName.isNotEmpty == true ? p!.babyName : 'Nanit',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: LText(status, style: sub()),
          trailing: firmware == null ? null : LText.raw(firmware, style: sub()),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          title: const LText(
            'Camera address',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: LText(p?.manualIp ?? 'Found automatically', style: sub()),
          trailing: Icon(Icons.chevron_right_rounded, color: Baby.muted),
          onTap: () => editCameraAddress(context, hub),
        ),
        if (expires != null)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            title: const LText(
              'Works offline until',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: LText(
              hub.signedIn
                  ? whenLabel(expires.toLocal())
                  : '${whenLabel(expires.toLocal())} · sign in to renew',
              style: sub(),
            ),
          ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Icon(Icons.link_off_rounded, color: Baby.muted),
          title: const LText('Pick another camera'),
          onTap: hub.forgetCamera,
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Icon(Icons.logout_rounded, color: Baby.error),
          title: LText(
            'Sign out of Nanit',
            style: TextStyle(color: Baby.error),
          ),
          onTap: hub.signOut,
        ),
      ],
    );
  }
}

/// Asks for the camera's IP address, for when it is not found by itself.
Future<void> editCameraAddress(BuildContext context, NanitHub hub) async {
  final v = await showDialog<String>(
    context: context,
    builder: (_) => _AddressDialog(initial: hub.account.pairing?.manualIp),
  );
  if (v != null) await hub.setManualIp(v);
}

class _AddressDialog extends StatefulWidget {
  const _AddressDialog({this.initial});
  final String? initial;

  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
  late final _ip = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const LText('Camera address'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const LText(
          'Only needed if Nestling cannot find the camera by itself. '
          'Find it in your router’s list of devices.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ip,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onSubmitted: (v) => Navigator.pop(context, v),
          decoration: const LInputDecoration(hintText: '192.168.1.20'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, ''),
        child: const LText('Find it myself'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _ip.text),
        child: const LText('Save'),
      ),
    ],
  );
}

// --- Bits ---------------------------------------------------------------------

EdgeInsets _pagePadding(BuildContext context) =>
    EdgeInsets.fromLTRB(16, 0, 16, 32 + MediaQuery.paddingOf(context).bottom);

class _Intro extends StatelessWidget {
  const _Intro({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      IconBubble(
        glyph: (s, c) => Icon(icon, size: s, color: c),
        color: Baby.primarySoft,
        iconColor: Baby.primary,
        size: 64,
      ),
      const SizedBox(height: 12),
      LText(
        title,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 6),
      LText(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Baby.muted, fontWeight: FontWeight.w600),
      ),
    ],
  );
}

class _Problem extends StatelessWidget {
  const _Problem({required this.text, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Card(
    color: Baby.warn.withValues(alpha: 0.12),
    child: ListTile(
      leading: Icon(Icons.info_outline_rounded, color: Baby.warn),
      title: LText(text),
      trailing: action == null
          ? null
          : TextButton(onPressed: onAction, child: LText(action!)),
    ),
  );
}

/// The Camera button on Today: the room at a glance once a camera is
/// paired, a way to set one up before that.
class CameraTodayCard extends StatelessWidget {
  const CameraTodayCard({super.key, this.hub});
  final NanitHub? hub;

  @override
  Widget build(BuildContext context) {
    final h = hub ?? NanitHub.instance;
    return ListenableBuilder(
      listenable: h,
      builder: (context, _) {
        final paired = h.loaded && h.hasCamera;
        final c = h.client;
        final bits = <String>[
          if (c != null &&
              nanitActivityOf(c, NanitAlertKind.motion) == NanitActivity.now)
            'Moving now',
          if (c != null &&
              nanitActivityOf(c, NanitAlertKind.sound) == NanitActivity.now)
            'Sound now',
          if (c?.temperature != null)
            '${c!.temperature!.toStringAsFixed(1)} °C',
          if (c?.humidity != null) '${c!.humidity!.round()} %',
        ];
        final connected = h.connection?.connected ?? false;
        final subtitle = !paired
            ? 'Set up your Nanit camera'
            : bits.isNotEmpty
            ? bits.join(' · ')
            : connected
            ? 'Connected'
            : 'Not connected';
        final localSubtitle = h.local.saved == null
            ? subtitle
            : 'Home network · No account needed';
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: IconBubble(
              glyph: (s, col) =>
                  Icon(Icons.videocam_rounded, size: s, color: col),
              color: Baby.primarySoft,
              iconColor: Baby.primary,
              size: 40,
            ),
            title: const LText(
              'Camera',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: LText(
              localSubtitle,
              style: TextStyle(color: Baby.muted, fontWeight: FontWeight.w600),
            ),
            trailing: FilledButton.tonal(
              onPressed: () => openCamera(context),
              child: LText(paired ? 'Watch' : 'Set up'),
            ),
            onTap: () => openCamera(context),
          ),
        );
      },
    );
  }
}
