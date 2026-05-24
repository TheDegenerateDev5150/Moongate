import 'package:shared_preferences/shared_preferences.dart';

import '../models/printer_config.dart';
import 'network_discovery_service.dart';

/// Persists the list of paired printers to SharedPreferences.
class PrinterRegistry {
  PrinterRegistry._();
  static final PrinterRegistry instance = PrinterRegistry._();

  static const _key = 'moongate_printers';

  List<PrinterConfig> _printers = [];

  /// In-session map of which connection path won most recently for each
  /// printer.  Updated by [PrinterStatusService] after every successful poll,
  /// read by [PrinterScreen] when deciding which URL to load in the WebView.
  ///
  /// NOT persisted: on every cold start every printer begins with no live
  /// preference so the next session tries local first (same reason we don't
  /// persist [PrinterConfig.preferRemote] — see comment in the status service).
  final Map<String, bool> _livePreferRemote = {};

  List<PrinterConfig> get printers => List.unmodifiable(_printers);

  /// Returns the last-known live decision for [printerId], or null if no
  /// poll has succeeded yet this session.
  bool? livePreferRemote(String printerId) => _livePreferRemote[printerId];

  /// Called by [PrinterStatusService] each time a poll succeeds, so the
  /// printer-screen WebView and any other consumer can avoid wasting a
  /// 3-second timeout on a guaranteed-unreachable local IP.
  void setLivePreferRemote(String printerId, bool preferRemote) {
    _livePreferRemote[printerId] = preferRemote;
  }

  /// Pre-populate [_livePreferRemote] for every printer based on a cheap
  /// subnet comparison between the phone's current LAN and each printer's
  /// configured local IP.
  ///
  /// Why this exists:
  ///   The status service already discovers the right network path by
  ///   probing — but its first poll takes a 3 s local timeout before
  ///   falling back to the tunnel.  If the user cold-launches the app on
  ///   an unrelated network (e.g. visiting a friend) and taps a tile
  ///   *immediately*, the WebView would try the printer's local IP first,
  ///   either timing out or — worse — latching onto a 4xx/5xx from some
  ///   other device on the stranger's LAN that happens to answer at the
  ///   same IP.
  ///
  ///   By pre-checking subnets at app launch and on resume, the live
  ///   preference is already correct before any tile is even tapped, so
  ///   the WebView jumps straight to the tunnel with no flicker.
  ///
  /// Called from [main] on cold start and from the root app widget on
  /// every [AppLifecycleState.resumed] (in case the phone changed
  /// networks while the app was backgrounded).
  Future<void> refreshNetworkLocality() async {
    for (final printer in _printers) {
      // Tunnel-only printers (no remote host) can't be improved by this
      // check — there's nothing to fall back to.  Skip them.
      if (printer.remoteHost == null) continue;

      final sameSubnet = await NetworkDiscoveryService.instance
          .isOnSameSubnetAs(printer.host);

      // sameSubnet == false means the printer's LAN is unreachable from
      // here, regardless of what the host string looks like — prefer the
      // tunnel until a real poll says otherwise.  When subnets match, we
      // do NOT eagerly set _livePreferRemote = false: the status service
      // is still authoritative for actual reachability (think AP isolation,
      // printer powered off, etc.).
      if (!sameSubnet) {
        _livePreferRemote[printer.id] = true;
      }
    }
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return;
    try {
      _printers = PrinterConfig.listFromJson(raw);
    } catch (_) {
      // Saved data is corrupted or from an incompatible old version.
      // Clear it so the app starts clean rather than crashing every launch.
      _printers = [];
      await prefs.remove(_key);
    }
  }

  Future<void> add(PrinterConfig printer) async {
    _printers = [..._printers, printer];
    await _save();
  }

  Future<void> remove(String printerId) async {
    _printers = _printers.where((p) => p.id != printerId).toList();
    await _save();
  }

  /// Silently update the Cloudflare tunnel URL for a printer.
  /// Called automatically when the status poll returns a fresher URL
  /// than the one stored (Quick Tunnels rotate when cloudflared restarts).
  Future<void> updateRemoteHost(String printerId, String newRemoteHost) async {
    final idx = _printers.indexWhere((p) => p.id == printerId);
    if (idx == -1) return;
    if (_printers[idx].remoteHost == newRemoteHost) return;
    _printers = List.of(_printers)
      ..[idx] = _printers[idx].copyWith(remoteHost: newRemoteHost);
    await _save();
  }

  /// Persist which connection path worked last for this printer.
  /// Called by [PrinterStatusService] after each successful poll so the
  /// next app launch tries the right path first without wasting time on
  /// a guaranteed timeout (e.g. a remote-only printer's local IP).
  Future<void> updatePreferRemote(String printerId, {required bool preferRemote}) async {
    final idx = _printers.indexWhere((p) => p.id == printerId);
    if (idx == -1) return;
    if (_printers[idx].preferRemote == preferRemote) return;
    _printers = List.of(_printers)
      ..[idx] = _printers[idx].copyWith(preferRemote: preferRemote);
    await _save();
  }

  /// Persist the webcam display-transform settings + target FPS for a printer.
  /// Called by [PrinterStatusService] whenever the Moongate status endpoint
  /// returns webcam info — so the cached values stay current and are applied
  /// from the first frame on the next app launch (before any poll completes).
  Future<void> updateWebcamInfo(
    String printerId, {
    required bool flipH,
    required bool flipV,
    required int  rotation,
    required int  targetFps,
  }) async {
    final idx = _printers.indexWhere((p) => p.id == printerId);
    if (idx == -1) return;
    final p = _printers[idx];
    if (p.webcamFlipH == flipH &&
        p.webcamFlipV == flipV &&
        p.webcamRotation == rotation &&
        p.webcamTargetFps == targetFps) {
      return; // nothing changed
    }
    _printers = List.of(_printers)
      ..[idx] = p.copyWith(
          webcamFlipH:     flipH,
          webcamFlipV:     flipV,
          webcamRotation:  rotation,
          webcamTargetFps: targetFps);
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, PrinterConfig.listToJson(_printers));
  }
}
