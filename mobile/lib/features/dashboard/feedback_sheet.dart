import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../models/printer_config.dart';
import '../../services/printer_status_registry.dart';
import '../../services/supabase_service.dart';

/// Bottom sheet for the drawer's "Report a problem" action.
///
/// Collects a free-text comment (+ optional contact and which-printer) and
/// attaches auto-diagnostics (app version, device, printer list) before
/// posting to the submit-feedback Edge Function. Deliberately light — the
/// goal is to turn "it says connected but idle" into a report we can act on
/// without a back-and-forth.
Future<void> showFeedbackSheet(
  BuildContext context,
  List<PrinterConfig> printers,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true, // grow with the keyboard
    showDragHandle: true,
    builder: (_) => _FeedbackSheet(printers: printers),
  );
}

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet({required this.printers});
  final List<PrinterConfig> printers;

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final _comment = TextEditingController();
  final _contact = TextEditingController();

  // null = "General / not printer-specific".
  String? _printerName;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Pre-select when there's exactly one printer — saves a tap and is almost
    // always what a single-printer user means.
    if (widget.printers.length == 1) {
      _printerName = widget.printers.single.name;
    }
    // Live enable/disable of the Send button as the comment is typed.
    _comment.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _comment.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<String> _describeDevice() async {
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final a = await info.androidInfo;
      return 'Android ${a.version.release} (API ${a.version.sdkInt}) — '
          '${a.manufacturer} ${a.model}';
    }
    if (Platform.isIOS) {
      final i = await info.iosInfo;
      return '${i.systemName} ${i.systemVersion} — ${i.utsname.machine}';
    }
    return Platform.operatingSystem;
  }

  Future<void> _send() async {
    final comment = _comment.text.trim();
    if (comment.isEmpty || _sending) return;
    setState(() => _sending = true);

    String? appVersion;
    String? platform;
    try {
      final info = await PackageInfo.fromPlatform();
      appVersion = '${info.version} (build ${info.buildNumber})';
    } catch (_) {/* best-effort */}
    try {
      platform = await _describeDevice();
    } catch (_) {/* best-effort */}

    final diagnostics = <String, dynamic>{
      'printer_count': widget.printers.length,
      'printers': widget.printers.map((p) {
        final s = PrinterStatusRegistry.instance.snapshot(p.id);
        return {
          'name': p.name,
          'lanUrl': p.lanUrl,
          'has_lan_url': p.lanUrl != null,
          'ui_type': p.uiType,
          'webcam_target_fps': p.webcamTargetFps,
          // Live state the dashboard last showed — connection path, whether the
          // tunnel is up, and the Klipper/synthetic state ('waiting', etc.).
          if (s != null)
            'live': {
              'state': s.state,
              'connection': s.connection.name,
              'tunnel_ready': s.tunnelReady,
              'has_webcam': s.webcamSnapshotUrl != null,
            },
        };
      }).toList(),
    };

    try {
      await SupabaseService.instance.submitFeedback(
        comment: comment,
        contact: _contact.text,
        printerName: _printerName,
        appVersion: appVersion,
        platform: platform,
        diagnostics: diagnostics,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks — your report was sent.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              "Couldn't send — check your connection and try again."),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSend = _comment.text.trim().isNotEmpty && !_sending;

    // Lift content above the keyboard; SafeArea(bottom) keeps Send clear of the
    // 3-button nav bar — the clipping we hit on the remove + PIN sheets before.
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.bug_report_outlined,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Text('Report a problem', style: theme.textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "Tell us what's happening. Your app version, device and printer "
                'list are attached automatically to help us track it down.',
                style:
                    theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
              ),
              const SizedBox(height: 16),

              // Which printer — only when there's a choice to make.
              if (widget.printers.isNotEmpty) ...[
                DropdownButtonFormField<String?>(
                  initialValue: _printerName,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Which printer? (optional)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('General / not printer-specific'),
                    ),
                    ...widget.printers.map(
                      (p) => DropdownMenuItem<String?>(
                        value: p.name,
                        child: Text(p.name),
                      ),
                    ),
                  ],
                  onChanged:
                      _sending ? null : (v) => setState(() => _printerName = v),
                ),
                const SizedBox(height: 12),
              ],

              TextField(
                controller: _comment,
                enabled: !_sending,
                minLines: 4,
                maxLines: 8,
                maxLength: 5000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'What went wrong?',
                  hintText:
                      'e.g. "Printer shows Connected / idle but it\'s actually '
                      'ready — opens fine when I tap the tile."',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              TextField(
                controller: _contact,
                enabled: !_sending,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email or contact (optional)',
                  hintText: 'Only if you want a reply',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: canSend ? _send : null,
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(_sending ? 'Sending…' : 'Send report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
