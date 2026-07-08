import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/settings_provider.dart';

/// A selectable UI language.
///
/// [code] is the language code stored in [localeProvider] (a `null` code means
/// "follow the device's system language"). [nativeName] is shown in the
/// language's own script and is intentionally the SAME in every locale - a
/// French speaker scanning the list looks for "Français", not "French".
class LanguageOption {
  final String code;
  final String nativeName;
  const LanguageOption(this.code, this.nativeName);
}

/// The languages Moongate ships full translations for. Keep this in sync with
/// the `lib/l10n/app_*.arb` files and `AppLocalizations.supportedLocales`.
/// English first (the default), then the rest of the 3D-printing community set.
const List<LanguageOption> kLanguageOptions = [
  LanguageOption('en', 'English'),
  LanguageOption('de', 'Deutsch'),
  LanguageOption('fr', 'Français'),
  LanguageOption('es', 'Español'),
  LanguageOption('it', 'Italiano'),
  LanguageOption('zh', '中文（简体）'),
  LanguageOption('ru', 'Русский'),
  LanguageOption('pl', 'Polski'),
  LanguageOption('pt_BR', 'Português (Brasil)'),
];

/// Native name for a stored language [code], or `null` if it isn't one we ship
/// (the caller then shows the "System default" label).
String? nativeLanguageName(String? code) {
  for (final o in kLanguageOptions) {
    if (o.code == code) return o.nativeName;
  }
  return null;
}

/// Show the language picker.
///
/// On [firstRun] the barrier is non-dismissible so the user makes an explicit
/// choice via the Continue button (the caller persists the "seen" flag after
/// this future completes). Opened from the menu it's a normal dismissible
/// dialog. Selecting a language applies it live, so the dialog itself - and the
/// app behind it - switch language immediately as a confirmation.
Future<void> showLanguagePicker(BuildContext context, {bool firstRun = false}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: !firstRun,
    builder: (_) => _LanguagePickerDialog(firstRun: firstRun),
  );
}

class _LanguagePickerDialog extends ConsumerWidget {
  const _LanguagePickerDialog({required this.firstRun});

  final bool firstRun;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final current = ref.watch(localeProvider); // null = system default

    return AlertDialog(
      title: Text(l.languagePickerTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                l.languagePickerSubtitle,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: RadioGroup<String?>(
                groupValue: current,
                onChanged: (code) =>
                    ref.read(localeProvider.notifier).set(code),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    RadioListTile<String?>(
                      value: null,
                      title: Text(l.languageSystemDefault),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    for (final o in kLanguageOptions)
                      RadioListTile<String?>(
                        value: o.code,
                        title: Text(o.nativeName),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.languagePickerContinue),
        ),
      ],
    );
  }
}
