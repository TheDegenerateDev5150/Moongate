// Print-progress maths shared by the dashboard tile ([PrinterStatusService])
// and the print notification ([PrintNotificationService]) so the two can never
// disagree — and so both match what Mainsail shows.
//
// They used to drift: the tile preferred an elapsed-time ÷ slicer-estimate
// calculation while the notification used the raw file fraction, and neither
// matched Mainsail's default. This is the single source of truth.

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
///   1. file-relative — needs [filePosition] + both valid gcode byte offsets
///   2. [displayProgress] — Klipper's `display_status.progress` (mirrors the
///      file fraction when the slice has no M73; honours M73 when it does)
///   3. [sdcardProgress]  — raw `virtual_sdcard.progress` (file-absolute)
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
