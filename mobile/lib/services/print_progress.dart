// Print-progress maths shared by the dashboard tile ([PrinterStatusService])
// and the print notification ([PrintNotificationService]) so the two can never
// disagree - and so both match what Mainsail shows.
//
// They used to drift: the tile preferred an elapsed-time ÷ slicer-estimate
// calculation while the notification used the raw file fraction, and neither
// matched Mainsail's default. This is the single source of truth.

import 'package:intl/intl.dart';

/// Print progress as a fraction in 0..1, computed to match Mainsail's default
/// **"file position (relative)"** mode: the printed byte position mapped onto
/// the slicer's gcode body, between [gcodeStartByte] and [gcodeEndByte], so the
/// file header (embedded thumbnails, config block) and trailing end-gcode don't
/// skew the percentage.
///
/// We deliberately do NOT use elapsed-time ÷ slicer-estimate: the slicer's
/// estimate is routinely off by 10-40%, which made the tile read several percent
/// ahead of Mainsail (the bug this replaces).
///
/// Fallback chain when the byte offsets or file position aren't known yet (e.g.
/// the file metadata hasn't loaded for the first second of a print):
///   1. file-relative - needs [filePosition] + both valid gcode byte offsets
///   2. [displayProgress] - Klipper's `display_status.progress` (mirrors the
///      file fraction when the slice has no M73; honours M73 when it does)
///   3. [sdcardProgress]  - raw `virtual_sdcard.progress` (file-absolute)
///   4. 0
double computePrintProgress({
  double? filePosition,
  int? gcodeStartByte,
  int? gcodeEndByte,
  double? displayProgress,
  double? sdcardProgress,
}) {
  if (filePosition != null &&
      gcodeStartByte != null &&
      gcodeEndByte != null &&
      gcodeEndByte > gcodeStartByte) {
    final rel =
        (filePosition - gcodeStartByte) / (gcodeEndByte - gcodeStartByte);
    return rel.clamp(0.0, 1.0);
  }
  if (displayProgress != null && displayProgress > 0) {
    return displayProgress.clamp(0.0, 1.0);
  }
  if (sdcardProgress != null && sdcardProgress > 0) {
    return sdcardProgress.clamp(0.0, 1.0);
  }
  return 0.0;
}

/// Print time remaining (seconds), estimated from elapsed ÷ progress with no
/// extra metadata call - the estimate the notification card has always shown,
/// now shared with the dashboard tile's ETA chip.
///
/// Null when there's nothing meaningful to show:
///   - not actively printing (a paused print's elapsed clock is frozen, so its
///     estimate silently goes stale - hide rather than mislead);
///   - too early to extrapolate (progress < 2% or < 30s elapsed - the maths
///     divides by a near-zero progress and produces garbage like "~43h");
///   - implausibly long (> 100h - a corrupt duration/progress pair).
double? printRemainingSeconds({
  required String state,
  required double progress,
  required double printDurationSec,
}) {
  if (state != 'printing') return null;
  if (progress < 0.02 || printDurationSec < 30) return null;
  final remaining = printDurationSec * (1 - progress) / progress;
  if (remaining <= 0 || remaining > 100 * 3600) return null;
  return remaining;
}

/// "1h05m" / "14m" - how much longer the print has to run.
String formatRemainingDuration(double seconds) {
  final d = Duration(seconds: seconds.round());
  final h = d.inHours;
  final m = d.inMinutes % 60;
  return h > 0 ? '${h}h${m.toString().padLeft(2, '0')}m' : '${m}m';
}

/// Wall-clock time the print is projected to finish ("1:20 AM" / "13:20"),
/// localised 12/24h via [localeName] - the same "ETA" Klipper and Mainsail
/// display. Null if the locale's date symbols didn't load, so callers fall
/// back to the remaining duration.
String? formatFinishClock(double remainingSeconds, String localeName) {
  try {
    final finish =
        DateTime.now().add(Duration(seconds: remainingSeconds.round()));
    return DateFormat.jm(localeName).format(finish);
  } catch (_) {
    return null;
  }
}
