/// The Moongate Pi-plugin version this app release shipped alongside.
///
/// Drives the dashboard's plugin-update badge: a tile whose /status reports an
/// older `plugin_version` than this shows the nudge. Bump it in the SAME PR as
/// any `klipper-plugin/moongate_standalone.py` MOONGATE_PLUGIN_VERSION bump -
/// the two travel together in a release, so the app always knows the newest
/// plugin that existed at its own release time. An app can only ever be
/// behind reality here (never ahead), so the badge can be late but never
/// false.
const String kCurrentPluginVersion = '0.6.16';

/// True when [reported] is an older plugin version than
/// [kCurrentPluginVersion]. A null/empty [reported] is a pre-v0.6.4 plugin
/// (those don't report a version at all), which is definitively outdated.
/// Unparseable strings compare as current so a custom build is never nagged.
bool pluginVersionIsOutdated(String? reported) {
  if (reported == null || reported.trim().isEmpty) return true;
  final cur = _parse(kCurrentPluginVersion);
  final rep = _parse(reported);
  if (cur == null || rep == null) return false;
  for (var i = 0; i < 3; i++) {
    if (rep[i] < cur[i]) return true;
    if (rep[i] > cur[i]) return false;
  }
  return false;
}

List<int>? _parse(String v) {
  final m = RegExp(r'^\s*v?(\d+)\.(\d+)(?:\.(\d+))?').firstMatch(v);
  if (m == null) return null;
  return [
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3) ?? '0'),
  ];
}
