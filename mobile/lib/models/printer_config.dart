import 'dart:convert';

class PrinterConfig {
  final String id;
  final String name;
  final String host; // tailscale IP:port, e.g. "100.64.0.2:7125"
  final String token;

  const PrinterConfig({
    required this.id,
    required this.name,
    required this.host,
    required this.token,
  });

  PrinterConfig copyWith({String? name}) =>
      PrinterConfig(id: id, name: name ?? this.name, host: host, token: token);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'token': token,
      };

  factory PrinterConfig.fromJson(Map<String, dynamic> j) => PrinterConfig(
        id: j['id'] as String,
        name: j['name'] as String,
        host: j['host'] as String,
        token: j['token'] as String,
      );

  static List<PrinterConfig> listFromJson(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => PrinterConfig.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String listToJson(List<PrinterConfig> printers) =>
      jsonEncode(printers.map((p) => p.toJson()).toList());
}

class PrinterStatus {
  final String state; // 'printing' | 'paused' | 'standby' | 'error' | 'offline'
  final double progress; // 0.0 – 1.0
  final double hotendTemp;
  final double hotendTarget;
  final double bedTemp;
  final double bedTarget;
  final String? filename;

  const PrinterStatus({
    required this.state,
    required this.progress,
    required this.hotendTemp,
    required this.hotendTarget,
    required this.bedTemp,
    required this.bedTarget,
    this.filename,
  });

  bool get isPrinting => state == 'printing' || state == 'paused';
  bool get isIdle => state == 'standby';

  static const offline = PrinterStatus(
    state: 'offline',
    progress: 0,
    hotendTemp: 0,
    hotendTarget: 0,
    bedTemp: 0,
    bedTarget: 0,
  );
}
