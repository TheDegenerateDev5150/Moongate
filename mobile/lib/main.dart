import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'providers/settings_provider.dart';
import 'services/printer_registry.dart';
import 'services/vpn_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await VpnService.instance.initialize();
  await PrinterRegistry.instance.load();
  // Decide per printer whether the phone's current LAN can plausibly reach
  // its local IP, BEFORE the dashboard is drawn.  Without this, cold-launching
  // on an unrelated network and tapping a tile immediately would wedge the
  // WebView on a doomed local URL until the 3 s fallback kicks in.
  await PrinterRegistry.instance.refreshNetworkLocality();

  final container = ProviderContainer();
  await container.read(themeModeProvider.notifier).load();
  await container.read(fontScaleProvider.notifier).load();
  await container.read(gridColumnsProvider.notifier).load();
  await container.read(allowRotationProvider.notifier).load();

  runApp(UncontrolledProviderScope(container: container, child: const MoongateApp()));
}
