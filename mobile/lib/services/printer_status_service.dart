import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/printer_config.dart';
import 'network_discovery_service.dart';
import 'printer_registry.dart';

/// Polls Moonraker's REST API to get current printer status.
/// One instance per printer tile; disposed when the tile leaves the tree.
///
/// Connection strategy (per candidate host — local first, then tunnel):
///   1. Try the Moongate plugin endpoint (/server/moongate/status).
///      Returns rich data: tunnel URL, webcam path, full print stats.
///   2. Fall back to the native Moonraker object query API.
///      Works even without the Moongate plugin installed.
///      Tries progressively simpler object sets to handle printers where
///      optional objects (heater_bed, display_status) are not configured.
///
/// Chamber sensor discovery:
///   On the first reachable connection, calls /printer/objects/list and
///   finds any temperature_sensor or heater_generic whose name contains
///   "chamber" (case-insensitive).  This handles every naming convention:
///   [temperature_sensor chamber], [temperature_sensor CHAMBER],
///   [temperature_sensor Chamber_Temp], [heater_generic CHAMBER], etc.
///   The discovered key is cached for the lifetime of this service instance.
///
/// A _polling guard prevents concurrent polls from stacking up when the
/// previous poll is still timing out on an unreachable host.
class PrinterStatusService {
  final PrinterConfig config;
  final _controller          = StreamController<PrinterStatus>.broadcast();
  final _tunnelUrlController = StreamController<String>.broadcast();
  final _probeController     = StreamController<String>.broadcast();
  Timer? _timer;
  bool _disposed = false;
  bool _polling  = false; // guard: skip tick if previous poll still running

  /// Mutable local copy of the connection preference — updated immediately
  /// on success so the very next poll uses the right order, and persisted
  /// to [PrinterRegistry] so the preference survives app restarts.
  bool _preferRemote;

  /// The Moonraker object key for the chamber temperature sensor, e.g.
  /// "temperature_sensor CHAMBER".  Null until discovery runs or when no
  /// chamber sensor is found.  Populated by [_discoverChamberSensor].
  String? _chamberKey;

  /// Set to true once discovery has been attempted (whether or not a sensor
  /// was found) so we don't call /printer/objects/list on every poll.
  bool _chamberDiscovered = false;

  /// Which web UI the printer is running — 'mainsail', 'fluidd', or null if
  /// not yet detected / unrecognised.  Detected once on the first reachable
  /// connection by fetching the root page and checking the HTML title.
  String? _uiType;
  bool    _uiTypeChecked = false;

  /// Slicer-estimated print time in seconds, from /server/files/metadata.
  /// Cached per-filename so we only fire one extra HTTP call per print file.
  /// Cleared when the filename changes so a new print gets fresh metadata.
  double? _estimatedPrintSeconds;
  String? _metadataFilename;

  /// When was the last time we (re)tried the local IP after having flipped
  /// to tunnel-first?  Used to throttle the "stuck on tunnel" recovery path
  /// in [_doPoll] — see the comment there.  Null = never tried (i.e. we've
  /// either always been on local, or we just flipped to tunnel-first and
  /// haven't given local a fresh chance yet).
  DateTime? _lastLocalRetry;

  /// How often to retry local when we're currently tunnel-first AND the
  /// phone's subnet matches the printer's.  20 s caps the worst-case cost
  /// at one 3-second local timeout per 5 poll cycles when the Pi is
  /// genuinely unreachable on LAN — barely noticeable.
  static const _localRetryInterval = Duration(seconds: 20);

  /// Exposes the detected UI type so tiles can show the right logo.
  String? get uiType => _uiType;

  // Seed [_preferRemote] from the registry's live (in-session, non-persisted)
  // preference.  Two paths feed that map BEFORE this constructor runs:
  //
  //   1. main.dart's [PrinterRegistry.refreshNetworkLocality] — pre-decides
  //      "tunnel-first" for any printer whose local IP isn't on the phone's
  //      current LAN, so the very first poll on a foreign network skips the
  //      doomed local probe.
  //   2. Previous polls in this same session — when the user navigates
  //      around and a new tile/service is created for an already-known
  //      printer, the last-known good path is reused.
  //
  // Falls back to local-first when there's no signal yet (a brand-new
  // printer, or no network info at app start).  We deliberately don't read
  // the *persisted* preferRemote here — that caused the "Tunnel" badge bug
  // on launch when the user was actually on the same LAN as the printer.
  PrinterStatusService(this.config)
      : _preferRemote =
            PrinterRegistry.instance.livePreferRemote(config.id) ?? false;

  Stream<PrinterStatus> get stream => _controller.stream;

  /// Emits the updated tunnel URL whenever the Pi reports a URL that differs
  /// from what is stored in the config.  Subscribe in the webcam widget to
  /// immediately start using the fresh URL within the same session.
  Stream<String> get tunnelUrlUpdates => _tunnelUrlController.stream;

  /// Emits which connection candidate is currently being probed:
  ///   'local'   — trying the local IP
  ///   'tunnel'  — trying the Cloudflare tunnel
  ///   'offline' — all candidates exhausted
  /// Used by the tile to show "Loading Local…" / "Loading Tunnel…" / "Offline"
  /// in the webcam area instead of a static offline state.
  Stream<String> get probePhase => _probeController.stream;

  void start({Duration interval = const Duration(seconds: 4)}) {
    _poll();
    _timer = Timer.periodic(interval, (_) => _poll());
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _controller.close();
    _tunnelUrlController.close();
    _probeController.close();
  }

  Future<void> _poll() async {
    if (_disposed || _polling) return;
    _polling = true;
    try {
      await _doPoll();
    } finally {
      _polling = false;
    }
  }

  Future<void> _doPoll() async {
    // ── Candidate ordering ────────────────────────────────────────────────
    //
    // Each printer remembers which path worked last (_preferRemote).
    // A printer on a completely different network (e.g. work printer)
    // has an unreachable local IP — without this, every 4-second poll
    // wastes a 2-second timeout on it before falling back to tunnel.
    //
    // Preference is updated automatically after each successful poll:
    //   • tunnel succeeds → _preferRemote = true  → tunnel tried first next time
    //   • local  succeeds → _preferRemote = false → local  tried first next time
    //
    // This means coming home automatically flips back to local-first as soon
    // as the local connection wins for the first time.
    final local  = config.host;
    final remote = config.remoteHost;

    // ── Periodic local retry ──────────────────────────────────────────────
    //
    // Once `_preferRemote` flips to `true` (e.g. one transient local-poll
    // failure at startup), the candidate order below would keep us on the
    // tunnel for the rest of the session — even after the user returns home
    // and is sitting on the printer's LAN.  The dashboard would show
    // "Tunnel" forever until the app is killed and reopened.
    //
    // To recover, periodically re-check the subnet relationship: if the
    // phone IS on the printer's LAN right now, try local first for this
    // one cycle.  Status-service's own `_onSuccess` will set `_preferRemote
    // = false` if local works, or `true` again if it doesn't (in which
    // case we wait `_localRetryInterval` before retrying).
    //
    // Worst-case cost on home WiFi with Pi unreachable: one extra 3 s
    // local timeout every 20 s (5 poll cycles) — barely noticeable, and
    // worth it to recover from "stuck on tunnel" automatically.
    bool retryingLocal = false;
    if (_preferRemote && remote != null) {
      final now = DateTime.now();
      final dueForRetry = _lastLocalRetry == null ||
          now.difference(_lastLocalRetry!) >= _localRetryInterval;
      if (dueForRetry) {
        final sameSubnet = await NetworkDiscoveryService.instance
            .isOnSameSubnetAs(local);
        if (sameSubnet) {
          retryingLocal   = true;
          _lastLocalRetry = now;
        }
      }
    }

    final candidates = (_preferRemote && remote != null && !retryingLocal)
        ? [remote, local]            // remote-preferred: skip local timeout
        : [local, if (remote != null) remote]; // local-first default

    for (final baseUrl in candidates) {
      final isRemote = remote != null && baseUrl == remote;

      // Tell the tile which candidate we're about to probe so it can show
      // "Loading Local…" or "Loading Tunnel…" with a spinner.
      if (!_disposed) _probeController.add(isRemote ? 'tunnel' : 'local');

      // Use a longer timeout for remote/tunnel connections: Cloudflare Quick
      // Tunnels can take 1-3 s to warm up after being idle, and general WAN
      // latency is higher than LAN.  A 2-second timeout fires before the
      // tunnel has a chance to respond, making the printer look "Offline"
      // even when the tunnel is working fine.
      final timeout  = isRemote
          ? const Duration(seconds: 8)  // tunnel: allow for cold-start latency
          : const Duration(seconds: 3); // local LAN: fast or not reachable

      // Discover the chamber sensor key on the first reachable host.
      // One extra HTTP call on the very first poll, zero overhead after that.
      if (!_chamberDiscovered) {
        await _discoverChamberSensor(baseUrl, timeout: timeout);
      }

      // ── 1. Moongate plugin endpoint (preferred) ──────────────────────────
      final moongate = await _tryMoongateEndpoint(baseUrl, timeout: timeout);
      if (moongate != null) {
        _onSuccess(baseUrl);
        if (!_disposed) _controller.add(moongate);
        return;
      }

      // ── 2. Native Moonraker API fallback ─────────────────────────────────
      //   Works even without the Moongate plugin.  Tries progressively
      //   simpler object sets to handle printers without a heated bed or
      //   other optional Klipper objects.
      final native = await _tryNativeEndpoint(baseUrl, timeout: timeout);
      if (native != null) {
        _onSuccess(baseUrl);
        if (!_disposed) _controller.add(native);
        return;
      }
    }

    // All candidates failed — printer is unreachable.
    if (!_disposed) {
      _probeController.add('offline');
      _controller.add(PrinterStatus.offline);
    }
  }

  // ── Chamber sensor discovery ───────────────────────────────────────────────
  //
  // Calls /printer/objects/list once and scans for any temperature_sensor or
  // heater_generic whose name contains "chamber" (case-insensitive).
  //
  // Examples this handles:
  //   [temperature_sensor chamber]      → key: "temperature_sensor chamber"
  //   [temperature_sensor CHAMBER]      → key: "temperature_sensor CHAMBER"
  //   [temperature_sensor Chamber_Temp] → key: "temperature_sensor Chamber_Temp"
  //   [heater_generic CHAMBER]          → key: "heater_generic CHAMBER"
  //
  // Sets _chamberDiscovered = true even if no sensor is found, so we don't
  // call /printer/objects/list on every subsequent poll.

  Future<void> _discoverChamberSensor(
      String baseUrl, {required Duration timeout}) async {
    try {
      final uri      = Uri.parse('$baseUrl/printer/objects/list');
      final response = await http.get(uri).timeout(timeout);
      if (response.statusCode == 200) {
        final body    = jsonDecode(response.body) as Map<String, dynamic>;
        final objects =
            ((body['result']?['objects']) as List<dynamic>?) ?? [];
        for (final obj in objects) {
          final key = obj.toString();
          // Match temperature_sensor, heater_generic, OR temperature_fan
          // (Micron+ and other enclosures often use temperature_fan for the
          // chamber fan which also exposes a temperature reading).
          if ((key.startsWith('temperature_sensor ') ||
               key.startsWith('heater_generic ') ||
               key.startsWith('temperature_fan ')) &&
              key.toLowerCase().contains('chamber')) {
            _chamberKey = key; // e.g. "temperature_sensor CHAMBER"
            break;
          }
        }
      }
      // Mark done regardless — avoids calling /printer/objects/list every poll
      // when the host is reachable but has no chamber sensor.
      _chamberDiscovered = true;
    } catch (_) {
      // Network error — leave _chamberDiscovered = false so we retry next poll
      // (the host may not have been reachable yet).
    }
  }

  /// Called after every successful poll.  Updates the in-session connection
  /// preference so the next poll in this session tries the right host first.
  /// NOT persisted — on app launch we always start local-first so a printer
  /// that was on a remote network last session doesn't keep trying tunnel
  /// first when you're back home on the same LAN.
  void _onSuccess(String baseUrl) {
    final isRemote = baseUrl != config.host;
    if (isRemote != _preferRemote) _preferRemote = isRemote;
    // Publish the live decision so the printer screen (and anyone else who
    // needs to make a network-path choice for this printer) doesn't repeat
    // the local-first probe and time out on a guaranteed-unreachable IP —
    // e.g. when the phone is on a different LAN to the printer.
    PrinterRegistry.instance.setLivePreferRemote(config.id, isRemote);
    // Fire-and-forget UI-type detection on the first successful connection.
    if (!_uiTypeChecked) _detectUiType(baseUrl);
  }

  // ── Web UI detection (Mainsail / Fluidd) ──────────────────────────────────
  //
  // Fetches the printer's root page once and sniffs the HTML <title> for
  // "Mainsail" or "Fluidd".  Result is cached for the session.
  // Called asynchronously — does not block polling.

  Future<void> _detectUiType(String baseUrl) async {
    _uiTypeChecked = true; // prevent concurrent calls
    try {
      final uri      = Uri.parse('$baseUrl/');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = response.body.toLowerCase();
        if (body.contains('mainsail')) {
          _uiType = 'mainsail';
        } else if (body.contains('fluidd')) {
          _uiType = 'fluidd';
        }
      }
    } catch (_) {
      // Detection failed — retry on next successful poll.
      _uiTypeChecked = false;
    }
  }

  // ── File metadata fetch (accurate progress) ───────────────────────────────
  //
  // Fetches estimated_time from /server/files/metadata for the file currently
  // being printed.  This is the same value Mainsail and Fluidd use:
  //   progress = print_duration / estimated_time
  //
  // Cached by filename — at most one HTTP call per print file.  Stale metadata
  // from the previous file is cleared immediately when the filename changes so
  // a new print never inherits the wrong estimate.  If the fetch fails, the
  // cache remains empty and progress falls back to display_status / virtual_sdcard.

  Future<void> _fetchFileMetadata(
      String baseUrl, String? filename, {required Duration timeout}) async {
    if (filename == null || filename.isEmpty) return;
    if (filename == _metadataFilename) return; // cache hit — same file
    // Clear stale metadata so a failed fetch falls back cleanly.
    _estimatedPrintSeconds = null;
    _metadataFilename      = null;
    try {
      final encoded  = Uri.encodeComponent(filename);
      final uri      = Uri.parse('$baseUrl/server/files/metadata?filename=$encoded');
      final response = await http.get(uri).timeout(timeout);
      if (response.statusCode == 200) {
        final body      = jsonDecode(response.body) as Map<String, dynamic>;
        final estimated = (body['result']?['estimated_time'] as num?)?.toDouble();
        if (estimated != null && estimated > 0) {
          _estimatedPrintSeconds = estimated;
          _metadataFilename      = filename;
        }
      }
    } catch (_) {
      // Metadata fetch failed — progress falls back to display_status / virtual_sdcard.
    }
  }

  // ── Moongate plugin endpoint ───────────────────────────────────────────────

  Future<PrinterStatus?> _tryMoongateEndpoint(
      String baseUrl, {required Duration timeout}) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/server/moongate/status?mg_token=${Uri.encodeComponent(config.token)}',
      );
      final response = await http.get(uri).timeout(timeout);
      if (response.statusCode != 200) return null;

      final body   = jsonDecode(response.body) as Map<String, dynamic>;
      final result = body['result'] as Map<String, dynamic>;
      // status is a plain Map — we may mutate it below to inject chamber data.
      final status = Map<String, dynamic>.from(
          result['status'] as Map<String, dynamic>);

      // Supplementary chamber query — for older plugin builds (e.g. v0.0.0-48
      // on the Micron+) that don't include the chamber sensor in their status
      // response.  If we discovered a chamber key but the plugin didn't return
      // data for it, fire one extra native call to fill it in.
      if (_chamberKey != null && status[_chamberKey!] == null) {
        await _supplementaryChamberQuery(baseUrl, status, timeout: timeout);
      }

      // Supplementary progress query — most Moongate plugin builds don't
      // include display_status or virtual_sdcard in their status response.
      // Without these, progress always shows 0 % even mid-print because
      // display_status.progress defaults to 0.0 until M73 is sent, and
      // virtual_sdcard.progress is simply absent.  Fetch both in one call
      // whenever either is missing from the plugin response.
      if (status['display_status'] == null || status['virtual_sdcard'] == null) {
        await _supplementaryProgressQuery(baseUrl, status, timeout: timeout);
      }

      // Fetch slicer-estimated print time for accurate progress calculation
      // (print_duration / estimated_time — the same formula Mainsail uses).
      final statsForMeta = status['print_stats'] as Map<String, dynamic>? ?? {};
      if (statsForMeta['state'] == 'printing') {
        await _fetchFileMetadata(
            baseUrl, statsForMeta['filename'] as String?, timeout: timeout);
      }
      return _parseStatus(status: status, moongateResult: result, baseUrl: baseUrl);
    } catch (_) {
      return null;
    }
  }

  /// Queries the chamber sensor directly via the native Moonraker API and
  /// injects the result into [status] in-place.
  ///
  /// Called when the Moongate endpoint succeeded but returned no data for the
  /// chamber key (older plugin builds that predate the chamber-sensor feature).
  Future<void> _supplementaryChamberQuery(
      String baseUrl,
      Map<String, dynamic> status, {
      required Duration timeout,
  }) async {
    try {
      final encoded  = Uri.encodeComponent(_chamberKey!);
      final uri      = Uri.parse('$baseUrl/printer/objects/query?$encoded');
      final response = await http.get(uri).timeout(timeout);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final s    = (body['result']?['status']) as Map<String, dynamic>?;
        final data = s?[_chamberKey!];
        if (data != null) status[_chamberKey!] = data;
      }
    } catch (_) {
      // Supplementary query failed — chamberTemp stays 0, not critical.
    }
  }

  /// Queries display_status and virtual_sdcard directly and injects them into
  /// [status] in-place.  Called when the Moongate endpoint response is missing
  /// these objects (all plugin builds prior to the progress-aware version).
  Future<void> _supplementaryProgressQuery(
      String baseUrl,
      Map<String, dynamic> status, {
      required Duration timeout,
  }) async {
    try {
      final uri = Uri.parse(
          '$baseUrl/printer/objects/query?display_status&virtual_sdcard');
      final response = await http.get(uri).timeout(timeout);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final s    = (body['result']?['status']) as Map<String, dynamic>?;
        if (s != null) {
          if (status['display_status'] == null && s['display_status'] != null) {
            status['display_status'] = s['display_status'];
          }
          if (status['virtual_sdcard'] == null && s['virtual_sdcard'] != null) {
            status['virtual_sdcard'] = s['virtual_sdcard'];
          }
        }
      }
    } catch (_) {
      // Supplementary query failed — progress stays 0, not critical.
    }
  }

  // ── Native Moonraker object query ──────────────────────────────────────────
  //
  // Moonraker returns HTTP 400 when you query an object that isn't registered
  // in the Klipper config (e.g. `heater_bed` on a printer without a heated
  // bed, or `display_status` on a printer without a display).  We try
  // progressively simpler object sets and stop at the first 200 response.
  // A timeout or any non-400 error causes an immediate bail-out.

  Future<PrinterStatus?> _tryNativeEndpoint(
      String baseUrl, {required Duration timeout}) async {
    // Build the query list dynamically.  If we've discovered the chamber sensor
    // key, prepend a query that includes it — the app will try that first and
    // only fall back to the no-chamber queries if it returns 400.
    final chamberParam = _chamberKey != null
        ? '&${Uri.encodeComponent(_chamberKey!)}'
        : '';
    final queries = [
      if (chamberParam.isNotEmpty)
        'print_stats&extruder&heater_bed&display_status&virtual_sdcard$chamberParam',
      'print_stats&extruder&heater_bed&display_status&virtual_sdcard',
      'print_stats&extruder&display_status&virtual_sdcard',
      'print_stats&display_status&virtual_sdcard',
      'print_stats',
    ];

    for (final q in queries) {
      try {
        final uri = Uri.parse('$baseUrl/printer/objects/query?$q');
        final response = await http.get(uri).timeout(timeout);

        if (response.statusCode == 200) {
          final body   = jsonDecode(response.body) as Map<String, dynamic>;
          final result = body['result'] as Map<String, dynamic>;
          final status = result['status'] as Map<String, dynamic>;
          // Fetch slicer-estimated print time for accurate progress.
          final statsForMeta = status['print_stats'] as Map<String, dynamic>? ?? {};
          if (statsForMeta['state'] == 'printing') {
            await _fetchFileMetadata(
                baseUrl, statsForMeta['filename'] as String?, timeout: timeout);
          }
          return _parseStatus(
              status: status, moongateResult: null, baseUrl: baseUrl);
        }

        // 400 = object not found → try a simpler query set
        if (response.statusCode == 400) continue;

        // Any other non-200 (401, 403, 5xx …) → give up on this host
        return null;
      } catch (_) {
        // Timeout or network error → give up on this host immediately
        // (don't bother retrying simpler queries — the host is unreachable)
        return null;
      }
    }
    return null;
  }

  // ── Shared status parser ───────────────────────────────────────────────────

  PrinterStatus _parseStatus({
    required Map<String, dynamic> status,
    required Map<String, dynamic>? moongateResult,
    required String baseUrl,
  }) {
    final printStats = status['print_stats'] as Map<String, dynamic>? ?? {};
    final extruder   = status['extruder']    as Map<String, dynamic>? ?? {};
    final heaterBed  = status['heater_bed']  as Map<String, dynamic>? ?? {};

    // Chamber temperature — look up by discovered key first, then fall back to
    // common hardcoded names.  The fallback covers:
    //   • Printers using the Moongate plugin before it also started querying
    //     the chamber sensor server-side.
    //   • Edge cases where discovery hasn't completed yet on the first frame.
    Map<String, dynamic>? chamberSensor = _chamberKey != null
        ? status[_chamberKey!] as Map<String, dynamic>?
        : null;
    chamberSensor ??=
        (status['temperature_sensor chamber'] ??
         status['temperature_sensor CHAMBER'] ??
         status['temperature_sensor chamber_temp'] ??
         status['temperature_sensor CHAMBER_TEMP'] ??
         status['heater_generic chamber'] ??
         status['heater_generic CHAMBER'] ??
         status['temperature_fan chamber'] ??
         status['temperature_fan CHAMBER']) as Map<String, dynamic>?;

    // display_status.progress is the real slicer % (set by M73 from the slicer,
    // or calculated by Klipper from virtual_sdcard position if no M73 is sent).
    // This is the same value Mainsail/Fluidd show.
    //
    // Now available from both the Moongate endpoint AND the native endpoint
    // (display_status is a built-in Klipper module, always present).
    final displayStatus  = status['display_status']  as Map<String, dynamic>? ?? {};
    final virtualSdcard  = status['virtual_sdcard']  as Map<String, dynamic>? ?? {};

    // When Klipper is still initialising, print_stats is present in the
    // Moonraker response but its 'state' field is null/absent.  Return
    // 'startup' rather than 'offline' so the badge says "Starting" instead of
    // "Offline" — the connection is working, Klipper just isn't ready yet.
    final state = (printStats['state'] as String?) ?? 'startup';

    // Progress — mirrors Mainsail/Fluidd exactly:
    //   1. print_duration / estimated_time  — the formula Mainsail and Fluidd
    //      use.  estimated_time comes from slicer-generated file metadata
    //      fetched via /server/files/metadata once per file and cached.
    //      Only active while printing and when the slicer embeds an estimate.
    //   2. display_status.progress          — set by M73 gcode from the slicer.
    //      Klipper initialises this to 0.0; treat 0.0 as "not yet set" and
    //      fall through, otherwise a printer with no M73 shows 0% forever.
    //   3. virtual_sdcard.progress          — file-read position (0→1).
    //      Reads slightly ahead due to look-ahead buffering but is non-zero
    //      once printing starts; last resort when metadata is unavailable.
    final double printDuration =
        (printStats['print_duration'] as num?)?.toDouble() ?? 0.0;
    final double displayProg =
        (displayStatus['progress'] as num?)?.toDouble() ?? 0.0;
    final double sdcardProg =
        (virtualSdcard['progress'] as num?)?.toDouble() ?? 0.0;

    final double progress;
    if (_estimatedPrintSeconds != null &&
        _estimatedPrintSeconds! > 0 &&
        printDuration > 0 &&
        state == 'printing') {
      progress = (printDuration / _estimatedPrintSeconds!).clamp(0.0, 1.0);
    } else if (displayProg > 0.0) {
      progress = displayProg.clamp(0.0, 1.0);
    } else if (sdcardProg > 0.0) {
      progress = sdcardProg.clamp(0.0, 1.0);
    } else {
      progress = 0.0;
    }

    // Detect tunnel URL rotation — only available from the Moongate endpoint.
    if (moongateResult != null && !_disposed) {
      final liveTunnelUrl = moongateResult['tunnel_url'] as String?;
      if (liveTunnelUrl != null &&
          liveTunnelUrl.isNotEmpty &&
          liveTunnelUrl != config.remoteHost) {
        _tunnelUrlController.add(liveTunnelUrl);
        PrinterRegistry.instance
            .updateRemoteHost(config.id, liveTunnelUrl)
            .ignore();
      }

      // Persist webcam transform settings so the tile is correct from the
      // very first frame on the next launch — before any poll completes.
      final flipH    = (moongateResult['webcam_flip_horizontal'] as bool?) ?? false;
      final flipV    = (moongateResult['webcam_flip_vertical']   as bool?) ?? false;
      final rotation = (moongateResult['webcam_rotation']    as num?)?.toInt() ?? 0;
      final fps      = (moongateResult['webcam_target_fps']  as num?)?.toInt() ?? 15;
      PrinterRegistry.instance.updateWebcamInfo(
        config.id,
        flipH:     flipH,
        flipV:     flipV,
        rotation:  rotation,
        targetFps: fps,
      ).ignore();
    }

    final connection = (baseUrl == config.host)
        ? PrinterConnection.local
        : PrinterConnection.remote;

    return PrinterStatus(
      state:              state,
      progress:           progress,
      hotendTemp:         (extruder['temperature']       as num?)?.toDouble() ?? 0,
      hotendTarget:       (extruder['target']            as num?)?.toDouble() ?? 0,
      bedTemp:            (heaterBed['temperature']      as num?)?.toDouble() ?? 0,
      bedTarget:          (heaterBed['target']           as num?)?.toDouble() ?? 0,
      chamberTemp:        (chamberSensor?['temperature'] as num?)?.toDouble() ?? 0,
      chamberTarget:      (chamberSensor?['target']      as num?)?.toDouble() ?? 0,
      filename:           printStats['filename']         as String?,
      connection:         connection,
      webcamSnapshotPath: moongateResult?['webcam_snapshot_path'] as String?,
      // Webcam display transforms — match whatever Mainsail has configured.
      // Only available via the Moongate endpoint; fall back to no-transform.
      webcamFlipH:     (moongateResult?['webcam_flip_horizontal'] as bool?) ?? false,
      webcamFlipV:     (moongateResult?['webcam_flip_vertical']   as bool?) ?? false,
      webcamRotation:  (moongateResult?['webcam_rotation']  as num?)?.toInt() ?? 0,
      // Crowsnest / Mainsail target FPS — drives the tile's snapshot poll
      // interval.  Default 15 if absent (stock Crowsnest setup).
      webcamTargetFps: (moongateResult?['webcam_target_fps'] as num?)?.toInt() ?? 15,
    );
  }
}
