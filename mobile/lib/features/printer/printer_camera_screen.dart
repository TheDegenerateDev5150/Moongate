import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/printer_config.dart';
import '../../services/printer_status_service.dart';
import '../../widgets/webcam_view.dart';

/// Full-screen, Moongate-native camera view for one printer.
///
/// Why this exists: the printer detail page embeds the real Mainsail/Fluidd UI
/// in a WebView, so its webcam panel inherits Mainsail's *own* camera URL. For
/// an external camera (e.g. an old phone running an IP-webcam app) that URL is
/// an absolute LAN address like `http://192.168.0.107:8080/video`, which a
/// phone on mobile data simply can't reach — Mainsail shows "Error while
/// connecting to …". This view sidesteps that entirely by rendering the camera
/// through the SAME resolved snapshot URL the dashboard tile uses: LAN-direct at
/// home, or routed through the Pi's owner-token-gated `/mg-extcam` proxy when
/// remote (the Pi is on the LAN, so it can reach the camera and relay it back
/// over the tunnel). So the external camera keeps working away from home — the
/// dashboard preview's behaviour, now available full-screen on the printer page.
class PrinterCameraScreen extends StatefulWidget {
  final PrinterConfig printer;
  const PrinterCameraScreen({super.key, required this.printer});

  @override
  State<PrinterCameraScreen> createState() => _PrinterCameraScreenState();
}

class _PrinterCameraScreenState extends State<PrinterCameraScreen> {
  late final PrinterStatusService _service;
  PrinterStatus? _status;

  @override
  void initState() {
    super.initState();
    // Run our own status poll so the snapshot URL (and its short-lived
    // mg_token) stays fresh while this view is open — the same service the
    // dashboard tile uses, so all the LAN-vs-tunnel / external-camera URL
    // resolution is reused, not reimplemented.
    _service = PrinterStatusService(widget.printer);
    _service.stream.listen((s) {
      if (mounted) setState(() => _status = s);
    });
    _service.start();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = _status;
    final url = s?.webcamSnapshotUrl;
    final hasCam = url != null && url.isNotEmpty;

    final isLocal = s?.connection == PrinterConnection.local;
    final subtitle = s == null || s.connection == PrinterConnection.offline
        ? null
        : (isLocal ? l.printerLocalNetwork : l.printerTunnelVia);

    Widget body;
    if (hasCam) {
      // Pinch-to-zoom / pan over a letterboxed live frame.
      body = InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: WebcamView(
          webcamSnapshotUrl: url,
          webcamFlipH: s!.webcamFlipH,
          webcamFlipV: s.webcamFlipV,
          webcamRotation: s.webcamRotation,
          webcamTargetFps: s.webcamTargetFps,
          webcamIsExternal: s.webcamIsExternal,
          uiType: _service.uiType ?? widget.printer.uiType,
          fit: BoxFit.contain,
          respectDashboardThrottle: false,
        ),
      );
    } else if (s == null) {
      body = _CenterMessage(spinner: true, text: l.cameraConnecting);
    } else if (s.connection == PrinterConnection.offline) {
      body = _CenterMessage(
        icon: Icons.cloud_off_outlined,
        text: l.printerUnreachable,
      );
    } else {
      body = _CenterMessage(
        icon: Icons.videocam_off_outlined,
        text: l.cameraNoCamera,
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.printer.name, overflow: TextOverflow.ellipsis),
            if (subtitle != null)
              Text(
                subtitle,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isLocal ? Colors.green : Colors.orange,
                    ),
              ),
          ],
        ),
      ),
      body: body,
    );
  }
}

class _CenterMessage extends StatelessWidget {
  final IconData? icon;
  final bool spinner;
  final String text;
  const _CenterMessage({this.icon, this.spinner = false, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (spinner)
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white54,
              ),
            )
          else if (icon != null)
            Icon(icon, size: 56, color: Colors.white30),
          const SizedBox(height: 16),
          Text(text, style: const TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}
