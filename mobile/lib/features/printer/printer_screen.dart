import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../models/printer_config.dart';
import '../../services/printer_access_cache.dart';
import '../../services/supabase_service.dart';

/// Full-screen WebView showing the printer's Mainsail/Fluidd interface.
///
/// v0.3.0 flow:
///   1. On init, ask Supabase for the printer's current tunnel URL via
///      [PrinterAccessCache] (which calls /printer-access under the hood).
///   2. Load `${tunnel_url}/` in the WebView. Mainsail's API calls reach
///      Moonraker on the Pi through the same tunnel.
///   3. If the URL fetch returns 503 (Pi hasn't heartbeated yet — fresh
///      pairing) we retry after a short delay.
///   4. If the URL becomes unreachable we surface an in-app error overlay
///      with a Retry button that re-fetches a fresh URL.
///
/// Note: Mainsail's web UI doesn't carry an EdDSA access token, so it
/// reaches native Moonraker endpoints through the tunnel un-authenticated.
/// That's the same model as v0.2.x — the security upgrade in v0.3.0 is
/// that control commands (which go through /server/moongate/control) now
/// require a fresh EdDSA token from Supabase, which only the legitimate
/// owner's signed-in app can mint.
class PrinterScreen extends StatefulWidget {
  final PrinterConfig printer;
  const PrinterScreen({super.key, required this.printer});

  @override
  State<PrinterScreen> createState() => _PrinterScreenState();
}

class _PrinterScreenState extends State<PrinterScreen>
    with WidgetsBindingObserver {
  WebViewController? _webController;

  bool    _loading   = true;
  String? _errorMsg;
  String? _tunnelUrl;
  Timer?  _retryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _tunnelUrl != null) {
      // Refresh in case the tunnel URL rotated while we were backgrounded.
      _start();
    }
  }

  Future<void> _start() async {
    setState(() { _loading = true; _errorMsg = null; });
    try {
      final access = await PrinterAccessCache.instance.get(widget.printer.id);
      if (!mounted) return;
      _tunnelUrl = access.tunnelUrl;
      _initControllerIfNeeded();
      await _webController!.loadRequest(Uri.parse('${access.tunnelUrl}/'));
    } on PrinterUnavailableException catch (e) {
      // Pi hasn't sent its first heartbeat — wait then retry.
      if (!mounted) return;
      setState(() {
        _loading  = false;
        _errorMsg = 'Printer is starting up. Retrying in ${e.retryAfter}s…';
      });
      _retryTimer = Timer(Duration(seconds: e.retryAfter), () {
        if (mounted) _start();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _errorMsg = 'Could not reach printer: $e'; });
    }
  }

  void _initControllerIfNeeded() {
    if (_webController != null) return;
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() { _loading = true; _errorMsg = null; });
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (err) {
          if (err.isForMainFrame != true) return;
          if (!mounted) return;
          setState(() {
            _loading  = false;
            _errorMsg = 'Cloudflare tunnel unreachable.\n${err.description}';
          });
        },
      ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.printer.name),
            Text(
              'Tunnel via Moongate',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.orange,
                  ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Re-fetch a fresh tunnel URL too — handles cloudflared rotation.
              PrinterAccessCache.instance.invalidate(widget.printer.id);
              _start();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_webController != null)
            WebViewWidget(controller: _webController!),

          if (_loading && _errorMsg == null)
            const Center(child: CircularProgressIndicator()),

          if (_errorMsg != null && !_loading)
            Container(
              color: cs.surface,
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off_outlined, size: 64, color: cs.error),
                  const SizedBox(height: 20),
                  Text(
                    'Printer unreachable',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(color: cs.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _errorMsg!,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: cs.onSurface.withValues(alpha: 0.7)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: () {
                      PrinterAccessCache.instance.invalidate(widget.printer.id);
                      _start();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
