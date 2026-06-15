import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../l10n/app_localizations.dart';
import '../../models/printer_config.dart';
import '../../providers/settings_provider.dart';
import '../../services/print_control_service.dart';
import '../../services/printer_registry.dart';
import '../../services/printer_status_registry.dart';
import '../../services/printer_status_service.dart';
import '../../widgets/webcam_view.dart';
import 'gcode_files_overlay.dart';

class PrinterTile extends StatefulWidget {
  final PrinterConfig printer;
  final VoidCallback onTap;

  const PrinterTile({super.key, required this.printer, required this.onTap});

  @override
  State<PrinterTile> createState() => _PrinterTileState();
}

class _PrinterTileState extends State<PrinterTile> with WidgetsBindingObserver {
  late final PrinterStatusService _statusService;
  late final PrintControlService _controlService;
  late PrinterStatus _status;

  bool _stopConfirmPending = false;
  Timer? _stopConfirmTimer;

  /// Web UI type — 'mainsail', 'fluidd', or null. Seeded from the persisted
  /// config (so a cold launch shows the logo immediately even if the
  /// printer is currently offline) and updated whenever the status service
  /// detects it for the first time on a fresh printer.
  String? _uiType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Seed the initial status with persisted webcam transform settings so the
    // first frame already shows the correct orientation — before any poll.
    // Use 'connecting' rather than 'offline' so the badge says "Connecting"
    // during the first poll instead of immediately flashing "Offline".
    _status = PrinterStatus(
      state:           'connecting',
      progress:        0,
      hotendTemp:      0,
      hotendTarget:    0,
      bedTemp:         0,
      bedTarget:       0,
      connection:      PrinterConnection.offline,
      webcamFlipH:     widget.printer.webcamFlipH,
      webcamFlipV:     widget.printer.webcamFlipV,
      webcamRotation:  widget.printer.webcamRotation,
      webcamTargetFps: widget.printer.webcamTargetFps,
    );
    _statusService = PrinterStatusService(widget.printer);
    _controlService = PrintControlService(widget.printer);
    // Seed from persisted config so a cold launch can render the right
    // logo immediately — without waiting for the first detection round-trip.
    _uiType = widget.printer.uiType;
    _statusService.stream.listen((s) {
      // Record the latest live status for the bug-report diagnostics, even if
      // this tile is no longer mounted — it's the most useful triage signal.
      PrinterStatusRegistry.instance.update(widget.printer.id, s);
      if (!mounted) return;
      final wasActive = _status.state == 'printing' || _status.state == 'paused';
      final isActive  = s.state == 'printing' || s.state == 'paused';
      // Print ended naturally while stop-confirm timer was still running —
      // clear the pending state so the button resets to "firmware restart".
      if (wasActive && !isActive && _stopConfirmPending) {
        _stopConfirmTimer?.cancel();
        _stopConfirmPending = false;
      }
      setState(() {
        _status = s;
        // Pick up UI type as soon as the service detects it.
        final detected = _statusService.uiType;
        if (detected != null && detected != _uiType) _uiType = detected;
      });
    });
    _statusService.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusService.dispose();
    _stopConfirmTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The OS may have frozen us (battery optimisation) and suspended the poll
    // timer. On return to the foreground, poll immediately so a stale 'offline'
    // tile refreshes at once instead of waiting up to a full cycle. The
    // app-level observer (app.dart) kicks the mDNS browse in parallel.
    if (state == AppLifecycleState.resumed) _statusService.pollNow();
  }

  Future<void> _handlePause() async {
    final ok = await _controlService.sendAction('pause');
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).tilePauseFailed),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleResume() async {
    final ok = await _controlService.sendAction('resume');
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).tileResumeFailed),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleStop() {
    final isIdle = _status.state != 'printing' && _status.state != 'paused';
    if (isIdle) {
      // Firmware restart when idle/error — brings Klipper back to ready state.
      _controlService.sendAction('firmware_restart');
      return;
    }
    if (_stopConfirmPending) {
      _stopConfirmTimer?.cancel();
      setState(() => _stopConfirmPending = false);
      _controlService.sendAction('cancel');
    } else {
      setState(() => _stopConfirmPending = true);
      _stopConfirmTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _stopConfirmPending = false);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).tileStopAgainToCancel),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Maps the current status to an overlay state, or null when the tile
  /// has a real reading to show.
  String? _overlayState(PrinterStatus s) {
    if (s.state == 'connecting')   return 'connecting';
    if (s.state == 'starting_up')  return 'starting_up';
    if (s.state == 'waiting')      return 'waiting';
    if (s.connection == PrinterConnection.offline) return 'offline';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);

    // Colours used for the connection indicator throughout the tile.
    final connColor = switch (_status.connection) {
      PrinterConnection.local   => Colors.green,
      PrinterConnection.remote  => Colors.orange,
      PrinterConnection.offline => Colors.transparent,
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Connection accent bar (clipped to card corners at top) ────
            Container(height: 3, color: connColor),

            // ── Webcam ───────────────────────────────────────────────────
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  WebcamView(
                    webcamSnapshotUrl: _status.webcamSnapshotUrl,
                    webcamFlipH:     _status.webcamFlipH,
                    webcamFlipV:     _status.webcamFlipV,
                    webcamRotation:  _status.webcamRotation,
                    webcamTargetFps: _status.webcamTargetFps,
                    webcamIsExternal: _status.webcamIsExternal,
                    uiType: _uiType,
                  ),
                  // Overlay shown while we don't yet have a usable
                  // status (first poll in flight, Pi waiting for its first
                  // heartbeat, or settled offline). When the UI type is
                  // known we fall through to the logo + a small status
                  // hint instead of a generic spinner — so a powered-off
                  // K3 still looks like the K3, not a blank loading tile.
                  if (_overlayState(_status) case final overlay?)
                    _ConnectionProbe(state: overlay, uiType: _uiType),
                  // ── Status badge ───────────────────────────────────────────
                  // Only shown when connected — the probe overlay provides the
                  // status context while offline/connecting.
                  if (_status.connection != PrinterConnection.offline &&
                      _status.state != 'connecting')
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _StatusBadge(status: _status),
                    ),
                  // Camera config gear (top-right). Lets the user point this
                  // tile at an external camera (e.g. a phone webcam). The
                  // button watches the "show camera icons" setting and renders
                  // nothing when it's off, so it never overlaps the feed.
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _CameraConfigButton(
                      printer: widget.printer,
                      onApplied: _statusService.pollNow,
                    ),
                  ),
                ],
              ),
            ),

            // ── Progress + buttons in ONE row ────────────────────────────
            // Hide action row when there's nothing to act on: offline,
            // Pi reachable but Klipper not responding ('waiting'), first
            // poll still in flight, Pi not heartbeating yet, or Klipper
            // itself still booting. TODO(v0.5+): show a "wake printer"
            // button in this row when state == 'waiting'.
            if (_status.state != 'offline' &&
                _status.state != 'connecting' &&
                _status.state != 'starting_up' &&
                _status.state != 'waiting' &&
                _status.state != 'startup')
              GestureDetector(
                onTap: () {}, // absorb — don't navigate when tapping controls
                behavior: HitTestBehavior.opaque,
                child: _ActionRow(
                  status: _status,
                  stopConfirmPending: _stopConfirmPending,
                  onPause: _handlePause,
                  onResume: _handleResume,
                  onStop: _handleStop,
                  onOpenFiles: () =>
                      showGcodeFilesSheet(context, widget.printer),
                ),
              ),

            // ── Name + temperatures ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Printer name + connection label on the same row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.printer.name,
                          style: theme.textTheme.titleSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_status.connection != PrinterConnection.offline) ...[
                        const SizedBox(width: 4),
                        Icon(
                          _status.connection == PrinterConnection.local
                              ? Icons.wifi_rounded
                              : Icons.cloud_outlined,
                          size: 11,
                          color: connColor,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          _status.connection == PrinterConnection.local
                              ? l.tileLocal
                              : l.tileTunnel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: connColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        // v0.5.0: when connected over LAN, show the remote
                        // (tunnel) status as a small background hint — a
                        // spinner-ish "connecting" pip while the Pi's tunnel
                        // is still coming up after a fresh pair / reboot, and
                        // a green check once the cloud knows the tunnel URL.
                        // On the tunnel path itself the badge already says so.
                        if (_status.connection == PrinterConnection.local)
                          _TunnelStatusDot(ready: _status.tunnelReady),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _TempChip(
                        icon: Icons.whatshot,
                        color: Colors.deepOrange,
                        temp: _status.hotendTemp,
                        target: _status.hotendTarget,
                      ),
                      const SizedBox(width: 8),
                      _TempChip(
                        icon: Icons.bed,
                        color: Colors.blue,
                        temp: _status.bedTemp,
                        target: _status.bedTarget,
                      ),
                      if (_status.chamberTemp > 0) ...[
                        const SizedBox(width: 8),
                        _TempChip(
                          icon: Icons.sensor_window,
                          color: Colors.teal,
                          temp: _status.chamberTemp,
                          target: _status.chamberTarget,
                        ),
                      ],
                    ],
                  ),
                  if (_status.filename != null && _status.isPrinting)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        _status.filename!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.white54),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Action row: progress bar / status label + buttons side-by-side ────────────

class _ActionRow extends StatelessWidget {
  final PrinterStatus status;
  final bool stopConfirmPending;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onStop;
  final VoidCallback onOpenFiles;

  const _ActionRow({
    required this.status,
    required this.stopConfirmPending,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onOpenFiles,
  });

  @override
  Widget build(BuildContext context) {
    final theme    = Theme.of(context);
    final l        = AppLocalizations.of(context);
    final printing = status.state == 'printing';
    final paused   = status.state == 'paused';
    final active   = printing || paused;
    final color    = paused ? Colors.orange : theme.colorScheme.primary;
    // "Ready to accept a print": online and idle/finished — not while printing
    // or paused (hide the folder then), and not on error/startup where Klipper
    // can't take a job yet. So it disappears mid-print and returns on complete.
    final ready = !active &&
        (status.state == 'standby' ||
         status.state == 'complete' ||
         status.state == 'cancelled');

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Left: progress bar (active) OR status label (idle) ─────────
          Expanded(
            child: active
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            paused ? l.tilePaused : l.tilePrinting,
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: color),
                          ),
                          Text(
                            '${(status.progress * 100).toStringAsFixed(1)}%',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: status.progress,
                          minHeight: 7,
                          backgroundColor: Colors.black26,
                          color: color,
                        ),
                      ),
                    ],
                  )
                : _IdleLabel(status: status),
          ),

          const SizedBox(width: 8),

          // ── Right: icon buttons ────────────────────────────────────────
          if (paused)
            _Btn(
              icon: Icons.play_arrow_rounded,
              color: Colors.green,
              tooltip: l.tileResume,
              onTap: onResume,
            ),
          if (printing)
            _Btn(
              icon: Icons.pause_rounded,
              color: Colors.orange,
              tooltip: l.tilePause,
              onTap: onPause,
            ),
          // Print a stored file — only when online and ready to accept a job.
          if (ready)
            _Btn(
              icon: Icons.folder_open_rounded,
              color: theme.colorScheme.primary,
              tooltip: l.tileOpenFiles,
              onTap: onOpenFiles,
            ),
          // Stop (active) / Firmware Restart (idle) — always shown for online printers.
          const SizedBox(width: 4),
          _Btn(
            icon: active
                ? (stopConfirmPending
                    ? Icons.stop_circle_rounded
                    : Icons.stop_rounded)
                : Icons.restart_alt,
            color: active
                ? (stopConfirmPending ? Colors.red : Colors.redAccent)
                : Colors.orange,
            tooltip: active
                ? (stopConfirmPending ? l.tileConfirmStop : l.tileStopPrint)
                : l.tileFirmwareRestart,
            onTap: onStop,
          ),
        ],
      ),
    );
  }
}

class _IdleLabel extends StatelessWidget {
  final PrinterStatus status;
  const _IdleLabel({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final (label, icon, color) = switch (status.state) {
      'complete'  => (l.tilePrintComplete, Icons.check_circle_outline,  Colors.teal),
      'cancelled' => (l.tilePrintCancelled, Icons.cancel_outlined,      Colors.blueGrey),
      'error'     => (l.tilePrinterError,  Icons.error_outline,        Colors.red),
      'startup'   => (l.tileKlipperStarting, Icons.hourglass_empty,     Colors.blueGrey),
      _           => (l.tileReady,           Icons.check_circle_outline, Colors.blueGrey),
    };
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        // Flexible + ellipsis so a longer label ("Print complete", and longer
        // still in other languages) shrinks instead of overflowing the row
        // when the folder + restart buttons share a narrow multi-column tile.
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ── Small icon button ─────────────────────────────────────────────────────────

class _Btn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _Btn({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}

// ── Connection probe overlay ──────────────────────────────────────────────────
//
// Shown in the webcam area when the tile has nothing live to render —
// first poll in flight, Pi not heartbeating yet, or settled offline.
//
// When the web UI type is known (persisted on the printer config after the
// first successful poll), the overlay renders that logo as the background
// so a powered-off K3 still looks like the K3, instead of a blank spinner
// tile. When the UI type is unknown we fall back to a generic spinner /
// wifi-off icon.

class _ConnectionProbe extends StatelessWidget {
  /// 'connecting'  — first poll in flight
  /// 'starting_up' — Pi hasn't heartbeated to Supabase yet
  /// 'waiting'     — Pi reachable but its printer-side stack isn't
  ///                 (K3 printer power off, Klipper not running, etc.)
  /// 'offline'     — settled, nothing answers on any path
  final String  state;
  final String? uiType; // 'mainsail' | 'fluidd' | null

  const _ConnectionProbe({required this.state, this.uiType});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasLogo = uiType == 'mainsail' || uiType == 'fluidd';

    final label = switch (state) {
      'offline'     => l.tileOffline,
      'starting_up' => l.tileStartingUp,
      'waiting'     => l.tileConnected,
      _             => l.tileConnecting,
    };
    final sub = switch (state) {
      'offline'     => l.tilePrinterUnreachable,
      'starting_up' => l.tileWaitingForHeartbeat,
      'waiting'     => l.tilePrinterIdle,
      _             => l.tileReachingPrinter,
    };

    // Top accent: spinner for "in flight" states, wifi-off when offline,
    // nothing for 'waiting' (the logo + Connected label carries it).
    // When the logo is showing we always skip the accent — the logo is
    // the visual focus.
    Widget? accent;
    if (!hasLogo) {
      if (state == 'offline') {
        accent = const Icon(Icons.wifi_off, size: 32, color: Colors.white30);
      } else if (state == 'connecting' || state == 'starting_up') {
        accent = const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white54,
          ),
        );
      }
    }

    // With a logo, dim less so the logo reads through.
    final backdrop = hasLogo ? Colors.black54 : Colors.black87;

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: backdrop),
        if (hasLogo)
          Center(
            child: Opacity(
              opacity: 0.4,
              child: SvgPicture.asset(
                uiType == 'mainsail'
                    ? 'assets/icons/mainsail_logo.svg'
                    : 'assets/icons/fluidd_logo.svg',
                width: 130,
                fit: BoxFit.contain,
              ),
            ),
          ),
        // Status text — at the bottom when a logo is showing, centered
        // when it isn't.
        Align(
          alignment: hasLogo ? Alignment.bottomCenter : Alignment.center,
          child: Padding(
            padding: EdgeInsets.only(bottom: hasLogo ? 10 : 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (accent != null) ...[
                  accent,
                  const SizedBox(height: 10),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Remote (tunnel) status dot ────────────────────────────────────────────────
//
// Shown next to the "Local" label so the user can see, at a glance, whether
// remote access is also ready while they're on the home network:
//   • amber cloud-sync  — the Pi's tunnel isn't registered with the cloud yet
//     (fresh pair, or Pi still booting cloudflared). Remote won't work until
//     this resolves, but Local already does — so the tile is usable now.
//   • green cloud-done  — the cloud knows the tunnel URL; remote access works.
// This is the "pairing icon → green tick" affordance: pairing happens on-LAN,
// the tile goes Local instantly, and the tunnel finishes establishing in the
// background without blocking anything.

class _TunnelStatusDot extends StatelessWidget {
  final bool ready;
  const _TunnelStatusDot({required this.ready});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 5),
      child: Tooltip(
        message: ready ? l.tileRemoteReady : l.tileRemoteConnecting,
        child: Icon(
          ready ? Icons.cloud_done_rounded : Icons.cloud_sync_outlined,
          size: 11,
          color: ready ? Colors.green : Colors.orangeAccent,
        ),
      ),
    );
  }
}

// ── Status badge ──────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final PrinterStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (label, color) = switch (status.state) {
      'printing'   => (l.tilePrinting,      Colors.green),
      'paused'     => (l.tilePaused,        Colors.orange),
      'standby'    => (l.tileIdle,          Colors.blueGrey),
      'complete'   => (l.tileDone,          Colors.teal),
      'cancelled'  => (l.tileCancelled,     Colors.blueGrey),
      'error'      => (l.tileError,         Colors.red),
      // Klipper is reachable but hasn't finished initialising yet
      'startup'    => (l.tileStarting,      Colors.blueGrey),
      // Before the first poll completes
      'connecting' => (l.tileConnectingBadge, Colors.blueGrey),
      _            => (l.tileOffline,       Colors.black54),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

// ── Temperature chip ──────────────────────────────────────────────────────────

class _TempChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double temp;
  final double target;

  const _TempChip({
    required this.icon,
    required this.color,
    required this.temp,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: target > 0 ? color : Colors.white38),
        const SizedBox(width: 2),
        Text(
          '${temp.toStringAsFixed(0)}°',
          style: TextStyle(
            fontSize: 12,
            color: target > 0 ? Colors.white : Colors.white54,
          ),
        ),
        if (target > 0)
          Text(
            '/${target.toStringAsFixed(0)}°',
            style: const TextStyle(fontSize: 10, color: Colors.white54),
          ),
      ],
    );
  }
}

// ── Camera config button + dialog ─────────────────────────────────────────────
//
// A small, semi-transparent gear in the corner of the webcam. Tapping it lets
// the user point this tile at a camera that isn't connected to Klipper — e.g.
// an old phone running an IP-webcam app. Watches the "show camera icons"
// setting and renders nothing when it's off, so it never overlaps the feed.

class _CameraConfigButton extends ConsumerWidget {
  final PrinterConfig printer;
  final VoidCallback onApplied;

  const _CameraConfigButton({required this.printer, required this.onApplied});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(showCameraConfigIconsProvider)) {
      return const SizedBox.shrink();
    }
    final l = AppLocalizations.of(context);
    return Tooltip(
      message: l.cameraConfigTooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            final changed = await showCameraConfigDialog(context, printer);
            if (changed == true) onApplied();
          },
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(
              Icons.settings,
              size: 17,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ),
      ),
    );
  }
}

/// Edit dialog for a tile's custom camera URL. Returns true if the URL was
/// changed (set or cleared), false/null if the user cancelled. Persists the
/// change to [PrinterRegistry]; the caller pokes the status service to refresh.
Future<bool?> showCameraConfigDialog(
    BuildContext context, PrinterConfig printer) {
  final controller = TextEditingController(text: printer.customCameraUrl ?? '');
  return showDialog<bool>(
    context: context,
    builder: (context) {
      final l = AppLocalizations.of(context);
      String? error;
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> apply() async {
            final raw = controller.text.trim();
            if (raw.isEmpty) {
              // Empty = clear the override (fall back to the Klipper camera).
              await PrinterRegistry.instance
                  .updateCustomCameraUrl(printer.id, null);
              if (context.mounted) Navigator.pop(context, true);
              return;
            }
            final uri = Uri.tryParse(raw);
            final ok = uri != null &&
                (uri.scheme == 'http' || uri.scheme == 'https') &&
                uri.host.isNotEmpty;
            if (!ok) {
              setState(() => error = l.cameraConfigInvalid);
              return;
            }
            await PrinterRegistry.instance
                .updateCustomCameraUrl(printer.id, raw);
            if (context.mounted) Navigator.pop(context, true);
          }

          return AlertDialog(
            title: Text(l.cameraConfigTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.cameraConfigDescription,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: l.cameraConfigUrlLabel,
                    hintText: 'http://192.168.0.107:8080/video',
                    errorText: error,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    if (error != null) setState(() => error = null);
                  },
                  onSubmitted: (_) => apply(),
                ),
                const SizedBox(height: 10),
                Text(
                  l.cameraConfigRemoteNote,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).hintColor),
                ),
              ],
            ),
            actions: [
              if ((printer.customCameraUrl ?? '').isNotEmpty)
                TextButton(
                  onPressed: () async {
                    await PrinterRegistry.instance
                        .updateCustomCameraUrl(printer.id, null);
                    if (context.mounted) Navigator.pop(context, true);
                  },
                  child: Text(l.cameraConfigUseDefault),
                ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.commonCancel),
              ),
              FilledButton(
                onPressed: apply,
                child: Text(l.cameraConfigApply),
              ),
            ],
          );
        },
      );
    },
  );
}
