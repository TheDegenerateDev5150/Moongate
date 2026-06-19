import 'package:flutter_test/flutter_test.dart';

import 'package:moongate/services/print_progress.dart';

/// Locks the progress maths to Mainsail's default "file position (relative)"
/// mode. The headline case uses a real snapshot captured live from a print on
/// the Micron — at that moment the old elapsed-time calc read ~12% while
/// Mainsail (and now this) read ~10.85%.
void main() {
  group('computePrintProgress', () {
    test('file-relative matches Mainsail (real Micron snapshot)', () {
      // Live values: file_position 401193, gcode_start_byte 10286,
      // gcode_end_byte 3614739 → (401193-10286)/(3614739-10286) = 0.10845.
      final p = computePrintProgress(
        filePosition: 401193,
        gcodeStartByte: 10286,
        gcodeEndByte: 3614739,
        displayProgress: 0.11,
        sdcardProgress: 0.11037,
      );
      expect(p * 100, closeTo(10.845, 0.01));
    });

    test('byte offsets win over display/sdcard (no time-based path)', () {
      // Even when display/sdcard are present, the relative byte calc is used.
      final p = computePrintProgress(
        filePosition: 1812366, // halfway through the body below
        gcodeStartByte: 10286,
        gcodeEndByte: 3614739,
        displayProgress: 0.9, // bogus on purpose — must be ignored
        sdcardProgress: 0.9,
      );
      expect(p, closeTo(0.5, 0.001));
    });

    test('clamps below the start byte to 0 (still in the header)', () {
      expect(
        computePrintProgress(
          filePosition: 5000,
          gcodeStartByte: 10286,
          gcodeEndByte: 3614739,
        ),
        0.0,
      );
    });

    test('clamps past the end byte to 1 (end gcode)', () {
      expect(
        computePrintProgress(
          filePosition: 3700000,
          gcodeStartByte: 10286,
          gcodeEndByte: 3614739,
        ),
        1.0,
      );
    });

    test('falls back to display_status when offsets unknown', () {
      expect(
        computePrintProgress(displayProgress: 0.42, sdcardProgress: 0.40),
        closeTo(0.42, 1e-9),
      );
    });

    test('falls back to virtual_sdcard when no display progress', () {
      expect(computePrintProgress(sdcardProgress: 0.40), closeTo(0.40, 1e-9));
    });

    test('ignores invalid offsets (end <= start)', () {
      expect(
        computePrintProgress(
          filePosition: 401193,
          gcodeStartByte: 100,
          gcodeEndByte: 100,
          displayProgress: 0.11,
        ),
        closeTo(0.11, 1e-9),
      );
    });

    test('zero when nothing is known', () {
      expect(computePrintProgress(), 0.0);
    });
  });
}
