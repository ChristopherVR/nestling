import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nanit_camera/nanit_camera.dart';

import '../../localization.dart';
import '../../nanit_integration.dart';
import '../../nanit_wifi_setup.dart';
import '../theme.dart';
import 'camera_art.dart';
import 'camera_help.dart';
import 'camera_help_content.dart';
import 'camera_issues.dart';

/// The screens of local camera setup, one task each.
enum CameraSetupStep {
  intro,
  path,
  prepare,
  bluetooth,
  wifi,
  network,
  find,
  name,
  done,
}

/// Guided local camera setup: what to expect, one step per screen, and a
/// specific fix for whatever goes wrong. Also used from a saved camera to
/// change its Wi-Fi ([setupWifi]).
class CameraSetupWizard extends StatefulWidget {
  const CameraSetupWizard({
    super.key,
    required this.hub,
    required this.onAccount,
    this.onConnected,
    this.onSaving,
    this.setupWifi = false,
    this.wifiSetup,
    this.discover,
    this.save,
  });
  final NanitHub hub;

  /// "Use a Nanit account instead", or leaving when [setupWifi].
  final VoidCallback onAccount;

  /// "Start watching" on the last step.
  final VoidCallback? onConnected;

  /// True while saving and on the last step, so the host keeps showing the
  /// wizard although a camera is now saved.
  final ValueChanged<bool>? onSaving;

  /// Starts at the Bluetooth Wi-Fi steps.
  final bool setupWifi;

  /// For tests: the Bluetooth adapter, network search and saving.
  final NanitWifiSetup Function()? wifiSetup;
  final Future<Map<String, String>> Function()? discover;
  final Future<void> Function(String address, String name)? save;

  @override
  State<CameraSetupWizard> createState() => _CameraSetupWizardState();
}

class _CameraSetupWizardState extends State<CameraSetupWizard> {
  late final NanitWifiSetup _wifi = (widget.wifiSetup ?? NanitWifiSetup.new)();
  final _address = TextEditingController();
  final _name = TextEditingController(text: 'Nursery camera');
  final _ssid = TextEditingController(), _password = TextEditingController();
  late CameraSetupStep _step = widget.setupWifi
      ? CameraSetupStep.prepare
      : CameraSetupStep.intro;
  late bool _bluetooth = widget.setupWifi;
  Map<String, String> _found = {};
  String? _selectedBle, _chosenAddress;
  bool _searching = false, _searched = false, _saving = false;
  bool _hidden = false, _showPassword = false, _manualOpen = false;
  bool _wifiAccepted = false;

  /// The current step's problem, other than Bluetooth ones in [_wifi].
  CameraIssue? _issue;
  String? _detail;

  /// Whichever problem card the step shows, to scroll it into view.
  final _issueKey = GlobalKey();
  WifiSetupFault? _lastFault;

  @override
  void initState() {
    super.initState();
    final saved = widget.hub.local.saved;
    if (saved != null) {
      _name.text = saved.name;
      _address.text = saved.address;
    }
    _wifi.addListener(() {
      if (_wifi.fault != null && _wifi.fault != _lastFault) _revealIssue();
      _lastFault = _wifi.fault;
    });
  }

  /// Scrolls the newly shown problem card into view.
  void _revealIssue() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final card = _issueKey.currentContext;
      if (card != null && card.mounted) {
        Scrollable.ensureVisible(
          card,
          duration: const Duration(milliseconds: 300),
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  void _raise(CameraIssue issue, [String? detail]) {
    setState(() {
      _issue = issue;
      _detail = detail;
    });
    _revealIssue();
  }

  @override
  void dispose() {
    for (final c in [_address, _name, _ssid, _password]) {
      c.dispose();
    }
    _wifi.dispose();
    super.dispose();
  }

  List<CameraSetupStep> get _steps => [
    if (!widget.setupWifi) ...[CameraSetupStep.intro, CameraSetupStep.path],
    if (_bluetooth) ...[
      CameraSetupStep.prepare,
      CameraSetupStep.bluetooth,
      CameraSetupStep.wifi,
    ],
    CameraSetupStep.network,
    CameraSetupStep.find,
    CameraSetupStep.name,
    CameraSetupStep.done,
  ];

  bool get _busy => _searching || _saving || _wifi.busy;

  void _go(CameraSetupStep step) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_step == CameraSetupStep.bluetooth && step != CameraSetupStep.wifi) {
      unawaited(_wifi.stopScan());
    }
    setState(() {
      _step = step;
      _issue = null;
      _detail = null;
    });
  }

  void _next() {
    final steps = _steps;
    final i = steps.indexOf(_step);
    if (i + 1 < steps.length) _go(steps[i + 1]);
  }

  bool get _canGoBack =>
      _steps.indexOf(_step) > 0 && _step != CameraSetupStep.done && !_busy;

  void _back() {
    final steps = _steps;
    final i = steps.indexOf(_step);
    if (i > 0) _go(steps[i - 1]);
  }

  void _choosePath(bool bluetooth) {
    setState(() => _bluetooth = bluetooth);
    _go(bluetooth ? CameraSetupStep.prepare : CameraSetupStep.network);
  }

  Future<void> _discover() async {
    setState(() {
      _searching = true;
      _issue = null;
      _detail = null;
    });
    try {
      final found = await (widget.discover ?? widget.hub.local.discover)();
      if (!mounted) return;
      setState(() {
        _found = found;
        _searched = true;
        if (found.isEmpty) _manualOpen = true;
      });
      if (found.isEmpty) _raise(CameraIssue.cameraNotFound);
    } catch (_) {
      if (mounted) _raise(CameraIssue.searchFailed);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _useAddress(String address) {
    _chosenAddress = address;
    _go(CameraSetupStep.name);
  }

  void _useTypedAddress() {
    try {
      _useAddress(requireNanitLanAddress(_address.text.trim()));
    } on FormatException catch (e) {
      _raise(CameraIssue.invalidAddress, e.message);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _issue = null;
      _detail = null;
    });
    widget.onSaving?.call(true);
    try {
      final address = _chosenAddress!, name = _name.text;
      await (widget.save?.call(address, name) ??
          widget.hub.useLocalCamera(address, name: name));
      if (!mounted) return;
      setState(() => _saving = false);
      _go(CameraSetupStep.done);
    } catch (e) {
      widget.onSaving?.call(false);
      if (mounted) {
        setState(() => _saving = false);
        _raise(issueForAddError(e), e is FormatException ? e.message : null);
      }
    }
  }

  Future<void> _join() async {
    setState(() {
      _issue = null;
      _detail = null;
      _wifiAccepted = false;
    });
    try {
      final pending = _wifi.provision(
        _selectedBle!,
        _ssid.text,
        _password.text,
        hidden: _hidden,
      );
      _password.clear();
      await pending;
      if (!mounted || !_wifi.joined) return;
      _wifiAccepted = true;
      _go(CameraSetupStep.network);
    } on FormatException catch (e) {
      if (mounted) _raise(CameraIssue.wifiDetailsInvalid, e.message);
    }
  }

  void _scanAgain() {
    if (_step != CameraSetupStep.bluetooth) _go(CameraSetupStep.bluetooth);
    _selectedBle = null;
    unawaited(_wifi.scan());
  }

  void _toBluetooth() {
    setState(() => _bluetooth = true);
    _go(CameraSetupStep.prepare);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _wifi,
    builder: (context, _) => PopScope(
      canPop: !_canGoBack,
      onPopInvokedWithResult: (popped, _) {
        if (!popped && _canGoBack) _back();
      },
      child: _page(context, _content(context)),
    ),
  );

  Widget _page(BuildContext context, _StepContent c) {
    final t = Theme.of(context).textTheme;
    final numbered = _steps.where((s) => s != CameraSetupStep.intro).toList();
    final current = numbered.indexOf(_step) + 1;
    return Column(
      children: [
        if (current > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.page,
              Space.sm,
              Space.page,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: tr('Step $current of ${numbered.length}'),
                  child: ExcludeSemantics(
                    child: LinearProgressIndicator(
                      value: current / numbered.length,
                      borderRadius: BorderRadius.circular(Corners.xs),
                    ),
                  ),
                ),
                const SizedBox(height: Space.sm),
                LText(
                  'Step $current of ${numbered.length}',
                  style: t.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: SingleChildScrollView(
            key: ValueKey(_step),
            padding: const EdgeInsets.fromLTRB(
              Space.page,
              Space.md,
              Space.page,
              Space.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CameraIllustration(c.scene),
                const SizedBox(height: Space.xl),
                Semantics(
                  header: true,
                  child: LText(c.title, style: t.headlineSmall),
                ),
                const SizedBox(height: Space.sm),
                LText(c.body, style: t.bodyLarge),
                if (c.expect.isNotEmpty) ...[
                  const SizedBox(height: Space.lg),
                  _ExpectCard(c.expect),
                ],
                const SizedBox(height: Space.lg),
                ...c.children,
                if (!c.placesIssue) ..._issueCard(),
              ],
            ),
          ),
        ),
        _BottomBar(
          back: _canGoBack ? _back : null,
          primary: c.primary,
          onPrimary: _busy ? null : c.onPrimary,
          busy: _saving || (_wifi.busy && _step == CameraSetupStep.wifi),
          onHelp: c.help.isEmpty
              ? null
              : () => showCameraStepHelp(context, topicIds: c.help),
        ),
      ],
    );
  }

  List<Widget> _issueCard() => [
    if (_issue != null) ...[
      const SizedBox(height: Space.lg),
      CameraIssueCard(
        key: _issueKey,
        issue: _issue!,
        detail: _detail,
        actions: _actions,
      ),
    ],
  ];

  Map<CameraFixAction, VoidCallback> get _actions => {
    // The find step's own Search button is right above its problem card.
    if (_step == CameraSetupStep.find) ...{
      CameraFixAction.enterAddress: () => setState(() => _manualOpen = true),
      if (!_bluetooth) CameraFixAction.setUpWifi: _toBluetooth,
    },
    if (_step == CameraSetupStep.name) ...{
      CameraFixAction.retry: _save,
      CameraFixAction.searchAgain: () => _go(CameraSetupStep.find),
      CameraFixAction.enterAddress: () {
        _manualOpen = true;
        _go(CameraSetupStep.find);
      },
    },
    if (_step == CameraSetupStep.bluetooth || _step == CameraSetupStep.wifi)
      CameraFixAction.scanAgain: _scanAgain,
  };

  _StepContent _content(BuildContext context) => switch (_step) {
    CameraSetupStep.intro => _intro(context),
    CameraSetupStep.path => _path(context),
    CameraSetupStep.prepare => _prepare(),
    CameraSetupStep.bluetooth => _bluetoothStep(context),
    CameraSetupStep.wifi => _wifiStep(context),
    CameraSetupStep.network => _network(context),
    CameraSetupStep.find => _find(context),
    CameraSetupStep.name => _nameStep(context),
    CameraSetupStep.done => _done(),
  };

  _StepContent _intro(BuildContext context) => _StepContent(
    scene: CameraScene.overview,
    title: 'Your camera, at home',
    body: 'Watch and listen over your home network. No Nanit account or internet connection needed.',
    children: [
      const CameraInfoCard(
        title: 'What you get',
        icon: Icons.check_circle_outline,
        items: [
          'Live video and sound from the nursery',
          'Room temperature and humidity',
          'Night light and soothing sounds',
          'Optional sound and possible-cry alerts',
        ],
      ),
      const SizedBox(height: Space.md),
      const CameraInfoCard(
        title: 'Good to know',
        icon: Icons.info_outline,
        items: [
          'Works only while this device is on your home Wi-Fi, not away from home.',
          'No recordings, sleep reports, breathing or motion alerts. Keep the Nanit app for those.',
          'Nothing is uploaded: video goes straight from the camera to this device.',
          'Setup takes about 5 minutes.',
        ],
      ),
      const SizedBox(height: Space.md),
      Card(
        child: ListTile(
          leading: const Icon(Icons.person_outline),
          title: const LText('Use a Nanit account instead'),
          subtitle: const LText(
            'Adds motion alerts. Needs the internet about once a week.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: widget.onAccount,
        ),
      ),
    ],
    primary: 'Get started',
    onPrimary: _next,
    help: const [CameraTopicId.networks, CameraTopicId.motionAlerts],
  );

  _StepContent _path(BuildContext context) => _StepContent(
    scene: CameraScene.network,
    title: 'Is your camera already on your Wi-Fi?',
    body: 'If the camera works in the Nanit app at home today, it is already on your Wi-Fi.',
    children: [
      _ChoiceCard(
        icon: Icons.wifi,
        title: 'Already on Wi-Fi',
        text: 'It works in the Nanit app at home. Nestling just needs to find it.',
        onTap: () => _choosePath(false),
      ),
      const SizedBox(height: Space.md),
      _ChoiceCard(
        icon: Icons.bluetooth,
        title: 'Set up Wi-Fi',
        text: 'It is new, was reset, or you changed your router or Wi-Fi password. Takes about 3 minutes.',
        onTap: () => _choosePath(true),
      ),
      const SizedBox(height: Space.lg),
      const LText(
        'Not sure? Choose Already on Wi-Fi. If Nestling cannot find the camera, it will offer Wi-Fi setup.',
      ),
    ],
    help: const [CameraTopicId.networks, 'cameraNotFound'],
  );

  _StepContent _prepare() => _StepContent(
    scene: CameraScene.pairing,
    title: 'Put the camera in pairing mode',
    body: 'The camera receives your Wi-Fi details over Bluetooth, but only while it is in pairing mode.',
    expect: const [
      'Pairing mode does not reset or erase the camera.',
      'It lasts a few minutes. You can press the button again at any time.',
    ],
    children: const [
      NumberedSteps([
        'Plug the camera in and wait about a minute for it to start.',
        'Turn on Bluetooth on this device.',
        'Close the Nanit app on all phones and tablets.',
        'Press the Wi-Fi pairing button on the back of the camera.',
        'Wait until the night light flashes.',
      ]),
    ],
    primary: 'The light is flashing',
    onPrimary: _next,
    help: const [
      CameraTopicId.pairingMode,
      'bluetoothOff',
      'bluetoothPermission',
    ],
  );

  _StepContent _bluetoothStep(BuildContext context) {
    final fault = _wifi.fault;
    final scanIssue =
        fault == WifiSetupFault.bluetoothOff ||
            fault == WifiSetupFault.bluetoothUnavailable ||
            fault == WifiSetupFault.noCameraFound
        ? issueForWifiFault(fault!)
        : null;
    final s = Theme.of(context).colorScheme;
    return _StepContent(
      scene: CameraScene.bluetooth,
      title: 'Find your camera',
      body: 'Hold this device within 1–2 metres of the camera, then tap Look for camera.',
      expect: const [
        'Looking takes up to 15 seconds.',
        'Your camera shows up as Nanit_ followed by letters and numbers.',
      ],
      children: [
        FilledButton.tonalIcon(
          onPressed: _wifi.scanning || _busy ? null : _scanAgain,
          icon: const Icon(Icons.bluetooth_searching),
          label: LText(
            _wifi.scanning ? 'Looking for cameras…' : 'Look for camera',
          ),
        ),
        if (_wifi.scanning)
          const Padding(
            padding: EdgeInsets.only(top: Space.md),
            child: LinearProgressIndicator(),
          ),
        const SizedBox(height: Space.sm),
        RadioGroup<String>(
          groupValue: _selectedBle,
          onChanged: (v) => setState(() => _selectedBle = v),
          child: Column(
            children: [
              for (final d in _wifi.devices.values)
                Card(
                  child: RadioListTile<String>(
                    value: d.deviceId,
                    secondary: Icon(Icons.videocam_outlined, color: s.primary),
                    title: Text(d.name ?? tr('Nanit camera')),
                    subtitle: const LText('Nanit camera nearby'),
                  ),
                ),
            ],
          ),
        ),
        if (scanIssue != null) ...[
          const SizedBox(height: Space.sm),
          CameraIssueCard(
            key: _issueKey,
            issue: scanIssue,
            detail: _wifi.problem,
            actions: _actions,
          ),
        ],
      ],
      primary: 'Continue',
      onPrimary: _selectedBle == null ? null : _next,
      help: const [
        'bleNoCameraFound',
        'bluetoothOff',
        'bluetoothPermission',
        CameraTopicId.pairingMode,
      ],
    );
  }

  _StepContent _wifiStep(BuildContext context) {
    final fault = _wifi.fault;
    final joinIssue =
        fault == WifiSetupFault.rejected ||
            fault == WifiSetupFault.interrupted ||
            fault == WifiSetupFault.notNanit
        ? issueForWifiFault(fault!)
        : null;
    final busy = _wifi.busy;
    return _StepContent(
      scene: CameraScene.wifi,
      title: 'Enter your home Wi-Fi',
      body: 'Nestling sends these to the camera over Bluetooth, once. They are not saved.',
      children: [
        TextField(
          controller: _ssid,
          enabled: !busy,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: tr('Wi-Fi name'),
            hintText: tr('e.g. Home-WiFi'),
            helperText: tr(
              'Exactly as it shows in this device’s Wi-Fi list, including capitals.',
            ),
            helperMaxLines: 3,
          ),
        ),
        const SizedBox(height: Space.lg),
        TextField(
          controller: _password,
          enabled: !busy,
          obscureText: !_showPassword,
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: busy ? null : (_) => _join(),
          decoration: InputDecoration(
            labelText: tr('Wi-Fi password'),
            helperText: tr('Used once to connect your camera. Not saved.'),
            helperMaxLines: 2,
            suffixIcon: IconButton(
              tooltip: tr(_showPassword ? 'Hide password' : 'Show password'),
              icon: Icon(
                _showPassword ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const LText('Hidden network'),
          subtitle: const LText('Only if your router hides its name'),
          value: _hidden,
          onChanged: busy ? null : (v) => setState(() => _hidden = v),
        ),
        const _TipCard(
          'Tip: if your router has separate names such as “Home” and “Home-5G”, choose the one without 5G. 2.4 GHz reaches further through walls.',
        ),
        if (busy) ...[
          const SizedBox(height: Space.lg),
          const LinearProgressIndicator(),
          const SizedBox(height: Space.sm),
          const LText(
            'Keep the camera nearby. This can take up to two minutes.',
          ),
        ],
        if (joinIssue != null && _issue == null) ...[
          const SizedBox(height: Space.lg),
          CameraIssueCard(
            key: _issueKey,
            issue: joinIssue,
            detail: _wifi.problem,
            actions: _actions,
          ),
        ],
      ],
      primary: busy ? 'Connecting camera to Wi-Fi…' : 'Connect camera to Wi-Fi',
      onPrimary: _selectedBle == null ? null : _join,
      help: const ['wifiRejected', 'wifiInterrupted', 'wifiDetailsInvalid'],
    );
  }

  _StepContent _network(BuildContext context) => _StepContent(
    scene: CameraScene.network,
    title: 'Check this device’s Wi-Fi',
    body: 'Nestling finds the camera through your home Wi-Fi, so this device must be on the same network as the camera.',
    children: [
      if (_wifiAccepted) ...[
        const _SuccessNote(
          'The camera accepted the Wi-Fi details. It can take a minute to join.',
        ),
        const SizedBox(height: Space.md),
      ],
      const _CheckList(
        good: [
          'Your home Wi-Fi, the one the camera uses',
          'Mesh Wi-Fi, 2.4 GHz or 5 GHz',
        ],
        bad: ['A guest network', 'Mobile data', 'A VPN that is switched on'],
      ),
      if (_bluetooth) ...[
        const SizedBox(height: Space.md),
        const _TipCard(
          'If you just gave the camera a different Wi-Fi network, connect this device to that network too.',
        ),
      ],
    ],
    primary: 'This device is on the home Wi-Fi',
    onPrimary: _next,
    help: const [CameraTopicId.networks],
  );

  _StepContent _find(BuildContext context) => _StepContent(
    scene: CameraScene.search,
    title: 'Find the camera on your network',
    body: 'Nestling looks for Nanit cameras on this Wi-Fi. It takes up to 15 seconds.',
    children: [
      FilledButton.icon(
        onPressed: _busy ? null : _discover,
        icon: const Icon(Icons.search),
        label: LText(
          _searching
              ? 'Searching…'
              : _searched
              ? 'Search again'
              : 'Search my network',
        ),
      ),
      if (_searching)
        const Padding(
          padding: EdgeInsets.only(top: Space.md),
          child: LinearProgressIndicator(),
        ),
      if (_issue != CameraIssue.invalidAddress) ..._issueCard(),
      if (_found.isNotEmpty) ...[
        const SizedBox(height: Space.md),
        LText(
          'Tap your camera:',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        for (final e in _found.entries)
          Card(
            child: ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: Text(e.value),
              subtitle: Text(e.key),
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy ? null : () => _useAddress(e.key),
            ),
          ),
      ],
      const SizedBox(height: Space.md),
      Card(
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: ValueKey('manual-$_manualOpen'),
          initiallyExpanded: _manualOpen,
          shape: const Border(),
          collapsedShape: const Border(),
          onExpansionChanged: (v) => _manualOpen = v,
          leading: const Icon(Icons.pin_outlined),
          title: const LText('Enter the address yourself'),
          subtitle: const LText('If searching does not find it'),
          childrenPadding: const EdgeInsets.fromLTRB(
            Space.lg,
            0,
            Space.lg,
            Space.lg,
          ),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LText(
              'The address is four numbers with dots, for example 192.168.1.25. Find it in your router’s list of connected devices:',
            ),
            const SizedBox(height: Space.md),
            const RouterListExample(),
            const SizedBox(height: Space.md),
            TextButton.icon(
              onPressed: () =>
                  openCameraHelp(context, topicId: CameraTopicId.findAddress),
              icon: const Icon(Icons.help_outline_rounded),
              label: const LText('How do I find my router’s device list?'),
            ),
            const SizedBox(height: Space.sm),
            TextField(
              controller: _address,
              enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autocorrect: false,
              decoration: InputDecoration(
                labelText: tr('Camera IP address'),
                hintText: cameraAddressExample,
              ),
              onSubmitted: _busy ? null : (_) => _useTypedAddress(),
            ),
            const SizedBox(height: Space.md),
            OutlinedButton(
              onPressed: _busy ? null : _useTypedAddress,
              child: const LText('Connect by address'),
            ),
            if (_issue == CameraIssue.invalidAddress) ..._issueCard(),
          ],
        ),
      ),
    ],
    placesIssue: true,
    help: const [
      'cameraNotFound',
      CameraTopicId.networks,
      CameraTopicId.findAddress,
      CameraTopicId.routerChangedAddress,
    ],
  );

  _StepContent _nameStep(BuildContext context) => _StepContent(
    scene: CameraScene.overview,
    title: 'Name your camera',
    body: 'Give it a name you will recognise, then save it on this device.',
    expect: const [
      'Nestling checks it is really a Nanit camera before saving.',
      'Only the name, address and camera ID are saved. Never a password.',
    ],
    children: [
      Card(
        child: ListTile(
          leading: const Icon(Icons.router_outlined),
          title: const LText('Camera address'),
          subtitle: Text(_chosenAddress ?? ''),
          trailing: TextButton(
            onPressed: _busy ? null : () => _go(CameraSetupStep.find),
            child: const LText('Change'),
          ),
        ),
      ),
      const SizedBox(height: Space.lg),
      TextField(
        controller: _name,
        enabled: !_busy,
        maxLength: 60,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: tr('Camera name'),
          helperText: tr('For example Nursery or Grandma’s room'),
        ),
        onSubmitted: _busy ? null : (_) => _save(),
      ),
    ],
    primary: _saving ? 'Connecting…' : 'Save and connect',
    onPrimary: _save,
    help: const ['cannotReachAddress', 'notACamera', 'differentCamera'],
  );

  _StepContent _done() => _StepContent(
    scene: CameraScene.done,
    title: 'You are all set',
    body: 'Your camera is saved on this device.',
    children: const [
      CameraInfoCard(
        title: 'What to expect',
        icon: Icons.lightbulb_outline,
        items: [
          'Video starts muted. Tap Listen to hear the room.',
          'Video pauses when you leave the camera screen and reconnects when you return.',
          'If your router gives the camera a new address, Nestling finds it again by itself.',
          'Turn on Sound & cry alerts below the video if you want notifications.',
        ],
      ),
    ],
    primary: 'Start watching',
    onPrimary: () {
      widget.onSaving?.call(false);
      widget.onConnected?.call();
    },
    help: const ['noAudio', 'unreachable'],
  );
}

class _StepContent {
  const _StepContent({
    required this.scene,
    required this.title,
    required this.body,
    this.expect = const [],
    this.children = const [],
    this.primary,
    this.onPrimary,
    this.help = const [],
    this.placesIssue = false,
  });
  final CameraScene scene;
  final String title, body;

  /// "What to expect" lines.
  final List<String> expect;
  final List<Widget> children;

  /// The main button; none when the step's own choices move on.
  final String? primary;
  final VoidCallback? onPrimary;

  /// Help topic ids for "Something not working?".
  final List<String> help;

  /// The step puts the problem card itself; otherwise it goes at the end.
  final bool placesIssue;
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.back,
    required this.primary,
    required this.onPrimary,
    required this.busy,
    required this.onHelp,
  });
  final VoidCallback? back, onPrimary, onHelp;
  final String? primary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    return Material(
      color: s.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.md,
            vertical: Space.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (back != null)
                    TextButton.icon(
                      onPressed: back,
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: const LText('Back'),
                    ),
                  if (primary != null)
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: FilledButton(
                          onPressed: onPrimary,
                          child: busy
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: s.onSurface,
                                      ),
                                    ),
                                    const SizedBox(width: Space.md),
                                    Flexible(child: LText(primary!)),
                                  ],
                                )
                              : LText(primary!, textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                ],
              ),
              if (onHelp != null)
                TextButton.icon(
                  onPressed: onHelp,
                  icon: const Icon(Icons.help_outline_rounded),
                  label: const LText('Something not working?'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpectCard extends StatelessWidget {
  const _ExpectCard(this.lines);
  final List<String> lines;
  @override
  Widget build(BuildContext context) => CameraInfoCard(
    title: 'What to expect',
    icon: Icons.schedule,
    items: lines,
  );
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.text,
    required this.onTap,
  });
  final IconData icon;
  final String title, text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.colors;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Row(
            children: [
              Icon(icon, size: 28, color: s.onSurfaceVariant),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LText(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: Space.xs),
                    LText(
                      text,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: s.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: s.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckList extends StatelessWidget {
  const _CheckList({required this.good, required this.bad});
  final List<String> good, bad;
  @override
  Widget build(BuildContext context) {
    final s = context.colors;
    Widget row(String text, bool ok) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        ok ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
        color: ok ? context.nest.success.color : s.error,
      ),
      title: LText(text),
    );
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.lg,
          Space.md,
          Space.lg,
          Space.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LText('Works', style: t.titleSmall),
            for (final g in good) row(g, true),
            const SizedBox(height: Space.sm),
            LText('Does not work', style: t.titleSmall),
            for (final b in bad) row(b, false),
          ],
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(
        Icons.tips_and_updates_outlined,
        color: context.colors.onSurfaceVariant,
      ),
      title: LText(text),
    ),
  );
}

class _SuccessNote extends StatelessWidget {
  const _SuccessNote(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(
        Icons.check_circle_outline_rounded,
        color: context.nest.success.color,
      ),
      title: LText(text),
    ),
  );
}
