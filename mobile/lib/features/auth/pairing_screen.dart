import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';

import '../../models/printer_config.dart';
import '../../services/auth_service.dart';
import '../../services/printer_registry.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  final _codeController = TextEditingController();
  final _hostController = TextEditingController();
  final _nameController = TextEditingController();
  bool _scanning = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _hostController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pair() async {
    final code = _codeController.text.trim();
    final host = _hostController.text.trim();
    final name = _nameController.text.trim().isEmpty
        ? 'My Printer'
        : _nameController.text.trim();

    if (code.isEmpty || host.isEmpty) {
      setState(() => _error = 'Enter the printer IP:port and pairing code.');
      return;
    }
    setState(() { _loading = true; _error = null; });

    final result = await AuthService.instance.exchangeCode(
      host: host,
      code: code,
      deviceName: name,
    );

    if (!mounted) return;

    if (result.success) {
      final printer = PrinterConfig(
        id: const Uuid().v4(),
        name: name,
        host: host,
        token: AuthService.instance.token!,
      );
      await PrinterRegistry.instance.add(printer);
      context.go('/dashboard');
    } else {
      setState(() {
        _error = result.error ?? 'Pairing failed.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Printer'),
        leading: PrinterRegistry.instance.printers.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/dashboard'),
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Run MOONGATE_PAIR in your Klipper console, then enter the code or scan the QR.',
              style: TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Printer name',
                hintText: 'e.g. Ender 3 Pro',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _hostController,
              decoration: const InputDecoration(
                labelText: 'Printer Tailscale IP:port',
                hintText: '100.x.x.x:7125',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'Pairing code',
                      hintText: 'GATE-XXXX-XXXX',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: 'Scan QR',
                  onPressed: () => setState(() => _scanning = !_scanning),
                ),
              ],
            ),
            if (_scanning) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 240,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: MobileScanner(
                    onDetect: (capture) {
                      final raw = capture.barcodes.first.rawValue ?? '';
                      final match = RegExp(r'code=(GATE-[A-Z0-9]+-[A-Z0-9]+)')
                          .firstMatch(raw);
                      if (match != null) {
                        _codeController.text = match.group(1)!;
                        setState(() => _scanning = false);
                      }
                    },
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _pair,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }
}
