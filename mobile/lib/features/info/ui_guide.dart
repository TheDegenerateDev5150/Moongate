import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// Shows the dashboard icon guide as a centered popup.
///
/// The (long) list scrolls inside the dialog while the "Back to dashboard"
/// button stays pinned at the bottom of the popup. The dialog is centered and
/// height-capped so it never runs under the status bar or the bottom system
/// navigation bar.
Future<void> showUiGuide(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _UiGuideDialog(),
  );
}

class _UiGuideDialog extends StatelessWidget {
  const _UiGuideDialog();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    // Cap the scroll area to ~60% of the screen so the centered dialog (plus
    // its title and pinned button) always stays clear of the system bars.
    final maxHeight = MediaQuery.sizeOf(context).height * 0.6;

    return AlertDialog(
      title: Text(l.uiGuideTitle),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      content: SizedBox(
        width: double.maxFinite,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(l.uiGuideIntro,
                      style: Theme.of(context).textTheme.bodyMedium),
                ),

                _header(context, l.uiGuideSectionConnection),
                _row(Icons.wifi_rounded, Colors.green, l.uiGuideLocalTitle,
                    l.uiGuideLocalDesc),
                _row(Icons.cloud_outlined, cs.primary, l.uiGuideTunnelTitle,
                    l.uiGuideTunnelDesc),
                _row(Icons.cloud_done_rounded, Colors.green,
                    l.uiGuideTunnelReadyTitle, l.uiGuideTunnelReadyDesc),
                _row(Icons.cloud_sync_outlined, Colors.orange,
                    l.uiGuideTunnelConnectingTitle,
                    l.uiGuideTunnelConnectingDesc),

                _header(context, l.uiGuideSectionTemperatures),
                _row(Icons.whatshot, Colors.deepOrange, l.uiGuideHotendTitle,
                    l.uiGuideHotendDesc),
                _row(Icons.bed, Colors.blue, l.uiGuideBedTitle,
                    l.uiGuideBedDesc),
                _row(Icons.sensor_window, Colors.teal, l.uiGuideChamberTitle,
                    l.uiGuideChamberDesc),

                _header(context, l.uiGuideSectionControls),
                _row(Icons.play_arrow_rounded, Colors.green,
                    l.uiGuideResumeTitle, l.uiGuideResumeDesc),
                _row(Icons.pause_rounded, Colors.orange, l.uiGuidePauseTitle,
                    l.uiGuidePauseDesc),
                _row(Icons.stop_rounded, Colors.redAccent, l.uiGuideStopTitle,
                    l.uiGuideStopDesc),
                _row(Icons.restart_alt, cs.primary,
                    l.uiGuideFirmwareRestartTitle,
                    l.uiGuideFirmwareRestartDesc),

                _header(context, l.uiGuideSectionTileButtons),
                _row(Icons.folder_open_rounded, cs.primary,
                    l.uiGuideFilesTitle, l.uiGuideFilesDesc),
                _row(Icons.code_rounded, cs.primary, l.uiGuideMacrosTitle,
                    l.uiGuideMacrosDesc),
                _row(Icons.power_settings_new, Colors.green,
                    l.uiGuidePowerTitle, l.uiGuidePowerDesc),
                _row(Icons.lightbulb, Colors.amber, l.uiGuideLightingTitle,
                    l.uiGuideLightingDesc),
                _row(Icons.visibility_outlined, cs.primary,
                    l.uiGuideCameraViewTitle, l.uiGuideCameraViewDesc),
                _row(Icons.settings, Colors.blueGrey,
                    l.uiGuideCameraSetupTitle, l.uiGuideCameraSetupDesc),

                _header(context, l.uiGuideSectionStatus),
                _row(Icons.check_circle_outline, Colors.teal,
                    l.uiGuideStatusReadyTitle, l.uiGuideStatusReadyDesc),
                _row(Icons.close_rounded, Colors.teal,
                    l.uiGuideClearJobTitle, l.uiGuideClearJobDesc),
                _row(Icons.cancel_outlined, Colors.blueGrey,
                    l.uiGuideStatusCancelledTitle,
                    l.uiGuideStatusCancelledDesc),
                _row(Icons.error_outline, Colors.redAccent,
                    l.uiGuideStatusErrorTitle, l.uiGuideStatusErrorDesc),
                _row(Icons.hourglass_empty, Colors.blueGrey,
                    l.uiGuideStatusStartingTitle, l.uiGuideStatusStartingDesc),

                _header(context, l.uiGuideSectionWebcam),
                _row(Icons.wifi_off, Colors.redAccent, l.uiGuideOfflineTitle,
                    l.uiGuideOfflineDesc),
                _row(Icons.videocam_off, Colors.blueGrey,
                    l.uiGuideNoWebcamTitle, l.uiGuideNoWebcamDesc),
              ],
            ),
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
          label: Text(l.uiGuideBack),
        ),
      ],
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 4),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
      );

  Widget _row(IconData icon, Color color, String title, String desc) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(desc),
      );
}
