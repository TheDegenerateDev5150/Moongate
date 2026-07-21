import 'package:flutter_test/flutter_test.dart';

import 'package:moongate/services/printer_access_cache.dart';
import 'package:moongate/services/supabase_service.dart';

/// A Direct-added printer's synthetic id ('lan-…') has no cloud row by
/// construction, so PrinterAccessCache must refuse it locally - before any
/// Supabase call. In this test environment Supabase is never initialized:
/// if the guard were missing, the lookup would blow up on the uninitialized
/// client instead of throwing the typed not-found, so a pass here proves no
/// network path was reached. (The prod symptom this locks out: the webview
/// cookie refresh minting for 'lan-http---192-168-1-84' every 4 minutes,
/// a 500 per attempt, July 2026.)
void main() {
  test('Direct-mode synthetic id fails locally with PrinterNotFound', () {
    expect(
      () => PrinterAccessCache.instance.get('lan-http---192-168-1-84'),
      throwsA(isA<PrinterNotFoundException>()),
    );
  });

  test('the guard is prefix-anchored, not a substring match', () {
    // A UUID id containing 'lan-' elsewhere must NOT trip the guard; it
    // should fall through toward a real lookup (which here fails on the
    // uninitialized Supabase client - anything but PrinterNotFound).
    expect(
      () => PrinterAccessCache.instance.get('0b5dlan-fake-uuid'),
      throwsA(isNot(isA<PrinterNotFoundException>())),
    );
  });
}
