import 'package:flutter/material.dart';

import '../../models/printer_config.dart';
import '../../services/diagnostics_service.dart';
import '../../services/supabase_service.dart';

/// Bottom sheet behind "Report a problem" (dashboard drawer) and "Trouble
/// pairing?" (Add Printer screen).
///
/// Collects a free-text comment (+ optional contact and which-printer) and
/// attaches a comprehensive diagnostics snapshot (see [DiagnosticsService])
/// before posting to the submit-feedback Edge Function. [pairingContext] is
/// supplied when launched from the pairing screen, so a user who can't pair —
/// and never reaches the dashboard — can still send a report carrying the live
/// discovery + attempt state.
Future<void> showFeedbackSheet(
  BuildContext context,
  List<PrinterConfig> printers, {
  Map<String, dynamic>? pairingContext,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true, // grow with the keyboard
    showDragHandle: true,
    builder: (_) =>
        _FeedbackSheet(printers: printers, pairingContext: pairingContext),
  );
}

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet({required this.printers, this.pairingContext});
  final List<PrinterConfig> printers;
  final Map<String, dynamic>? pairingContext;

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final _comment = TextEditingController();
  final _contact = TextEditingController();

  // null = "General / not printer-specific".
  String? _printerName;
  bool _sending = false;

  bool get _fromPairing => widget.pairingContext != null;

  @override
  void initState() {
    super.initState();
    // Pre-select when there's exactly one printer — saves a tap.
    if (widget.printers.length == 1) {
      _printerName = widget.printers.single.name;
    }
    _comment.addListener(() => setState(() {})); // live enable/disable Send
  }

  @override
  void dispose() {
    _comment.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final comment = _comment.text.trim();
    if (comment.isEmpty || _sending) return;
    setState(() => _sending = true);

    var diagnostics = <String, dynamic>{};
    try {
      diagnostics = await DiagnosticsService.collect(
        printers: widget.printers,
        pairingContext: widget.pairingContext,
      );
    } catch (_) {/* best-effort — send the comment regardless */}

    // Lift version + platform into the dedicated columns (easy dashboard
    // filtering); the full picture lives in `diagnostics`.
    String? appVersion;
    String? platform;
    final app = diagnostics['app'];
    if (app is Map) appVersion = '${app['version']} (build ${app['build']})';
    final dev = diagnostics['device'];
    if (dev is Map) {
      platform = dev['platform'] == 'android'
          ? '${dev['os']} — ${dev['manufacturer']} ${dev['model']}'
          : dev['os']?.toString();
    }

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
                  Text(_fromPairing ? 'Trouble pairing?' : 'Report a problem',
                      style: theme.textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _fromPairing
                    ? "Describe what happens when you try to add the printer. "
                        'Your network + discovery details are attached '
                        "automatically so we can see why it isn't connecting."
                    : "Tell us what's happening. Your app version, device, "
                        'network and printer details are attached automatically '
                        'to help us track it down.',
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
