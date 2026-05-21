import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/printer_config.dart';

/// Polls Moonraker's REST API to get current printer status.
/// One instance per printer tile; disposed when the tile leaves the tree.
class PrinterStatusService {
  final PrinterConfig config;
  final _controller = StreamController<PrinterStatus>.broadcast();
  Timer? _timer;

  PrinterStatusService(this.config);

  Stream<PrinterStatus> get stream => _controller.stream;

  void start({Duration interval = const Duration(seconds: 4)}) {
    _poll();
    _timer = Timer.periodic(interval, (_) => _poll());
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }

  Future<void> _poll() async {
    try {
      final uri = Uri.parse(
        'http://${config.host}/printer/objects/query'
        '?print_stats&heater_bed&extruder',
      );
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${config.token}'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        _controller.add(PrinterStatus.offline);
        return;
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final result = body['result'] as Map<String, dynamic>;
      final status = result['status'] as Map<String, dynamic>;

      final printStats = status['print_stats'] as Map<String, dynamic>? ?? {};
      final extruder = status['extruder'] as Map<String, dynamic>? ?? {};
      final heaterBed = status['heater_bed'] as Map<String, dynamic>? ?? {};

      final state = (printStats['state'] as String?) ?? 'offline';
      final progress = (printStats['print_duration'] != null &&
              printStats['total_duration'] != null &&
              (printStats['total_duration'] as num) > 0)
          ? ((printStats['print_duration'] as num) /
                  (printStats['total_duration'] as num))
              .clamp(0.0, 1.0)
          : 0.0;

      _controller.add(PrinterStatus(
        state: state,
        progress: progress.toDouble(),
        hotendTemp: (extruder['temperature'] as num?)?.toDouble() ?? 0,
        hotendTarget: (extruder['target'] as num?)?.toDouble() ?? 0,
        bedTemp: (heaterBed['temperature'] as num?)?.toDouble() ?? 0,
        bedTarget: (heaterBed['target'] as num?)?.toDouble() ?? 0,
        filename: printStats['filename'] as String?,
      ));
    } catch (_) {
      _controller.add(PrinterStatus.offline);
    }
  }
}
