import 'package:flutter/material.dart';
import 'package:nanit_camera/nanit_camera.dart';

import '../../localization.dart';
import 'camera_art.dart';
import 'camera_help.dart';
import 'camera_help_content.dart';

/// Asks for the camera's IP address with an example and where to find it.
/// Returns a checked private IPv4 address, '' for "find it automatically"
/// when [allowAutomatic], or null when cancelled.
Future<String?> showCameraAddressDialog(
  BuildContext context, {
  String? initial,
  bool allowAutomatic = false,
}) => showDialog<String>(
  context: context,
  builder: (_) =>
      _AddressDialog(initial: initial, allowAutomatic: allowAutomatic),
);

class _AddressDialog extends StatefulWidget {
  const _AddressDialog({this.initial, required this.allowAutomatic});
  final String? initial;
  final bool allowAutomatic;

  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
  late final _ip = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _ip.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      Navigator.pop(context, requireNanitLanAddress(_ip.text.trim()));
    } on FormatException {
      setState(
        () => _error = tr(
          'Four numbers with dots, starting 192.168., 10. or 172. For example 192.168.1.25.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const LText('Camera address'),
    scrollable: true,
    content: SizedBox(
      width: 420,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LText(
            'Find it in your router’s list of connected devices. Look for Nanit or a name starting with N3:',
          ),
          const SizedBox(height: 12),
          const RouterListExample(),
          const SizedBox(height: 16),
          TextField(
            controller: _ip,
            autofocus: true,
            autocorrect: false,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: tr('Camera IP address'),
              hintText: cameraAddressExample,
              errorText: _error,
              errorMaxLines: 3,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () =>
                  openCameraHelp(context, topicId: CameraTopicId.findAddress),
              icon: const Icon(Icons.help_outline),
              label: const LText('Where do I find this?'),
            ),
          ),
        ],
      ),
    ),
    actions: [
      if (widget.allowAutomatic)
        TextButton(
          onPressed: () => Navigator.pop(context, ''),
          child: const LText('Find it myself'),
        )
      else
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const LText('Cancel'),
        ),
      FilledButton(onPressed: _submit, child: const LText('Save')),
    ],
  );
}
