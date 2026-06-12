import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// First-run prompt offering to turn on print notifications. Non-dismissible so
/// the user makes an explicit choice; returns true if they tapped "Turn on".
/// The caller then requests the OS permission and enables the service.
Future<bool> showPrintNotificationsPrompt(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(l.printNotifPromptTitle),
      content: Text(l.printNotifPromptBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l.printNotifPromptNotNow),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l.printNotifPromptEnable),
        ),
      ],
    ),
  );
  return result ?? false;
}
