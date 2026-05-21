import 'package:flutter/material.dart';

import '../../models/printer_config.dart';
import '../../services/printer_status_service.dart';

class PrinterTile extends StatefulWidget {
  final PrinterConfig printer;
  final VoidCallback onTap;

  const PrinterTile({super.key, required this.printer, required this.onTap});

  @override
  State<PrinterTile> createState() => _PrinterTileState();
}

class _PrinterTileState extends State<PrinterTile> {
  late final PrinterStatusService _statusService;
  PrinterStatus _status = PrinterStatus.offline;

  @override
  void initState() {
    super.initState();
    _statusService = PrinterStatusService(widget.printer);
    _statusService.stream.listen((s) {
      if (mounted) setState(() => _status = s);
    });
    _statusService.start();
  }

  @override
  void dispose() {
    _statusService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Webcam snapshot
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _WebcamSnapshot(host: widget.printer.host, token: widget.printer.token),
                  // Status badge top-left
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _StatusBadge(status: _status),
                  ),
                  // Print progress overlay at bottom of image
                  if (_status.isPrinting)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        value: _status.progress,
                        minHeight: 4,
                        backgroundColor: Colors.black38,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
            // Info row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.printer.name,
                    style: theme.textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
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
                      if (_status.isPrinting) ...[
                        const Spacer(),
                        Text(
                          '${(_status.progress * 100).toStringAsFixed(1)}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_status.isPrinting && _status.filename != null)
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

class _WebcamSnapshot extends StatefulWidget {
  final String host;
  final String token;

  const _WebcamSnapshot({required this.host, required this.token});

  @override
  State<_WebcamSnapshot> createState() => _WebcamSnapshotState();
}

class _WebcamSnapshotState extends State<_WebcamSnapshot> {
  // Cache-bust the snapshot every 4 s
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) return false;
      setState(() => _tick++);
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final url =
        'http://${widget.host}/webcam?action=snapshot&_t=$_tick';
    return Image.network(
      url,
      fit: BoxFit.cover,
      headers: {'Authorization': 'Bearer ${widget.token}'},
      errorBuilder: (_, __, ___) => Container(
        color: Colors.black54,
        child: const Center(
          child: Icon(Icons.videocam_off, color: Colors.white30, size: 40),
        ),
      ),
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : Container(color: Colors.black54),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final PrinterStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status.state) {
      'printing' => ('Printing', Colors.green),
      'paused'   => ('Paused', Colors.orange),
      'standby'  => ('Idle', Colors.blueGrey),
      'error'    => ('Error', Colors.red),
      _          => ('Offline', Colors.black54),
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
