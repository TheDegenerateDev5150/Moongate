import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../models/printer_config.dart';
import '../../services/lan_discovery_service.dart';
import '../../services/printer_access_cache.dart';
import '../../services/printer_registry.dart';
import '../../services/supabase_service.dart';
import '../../widgets/keyboard_affordance.dart';

/// Full-screen WebView showing the printer's Mainsail/Fluidd interface.
///
/// Flow:
///   1. On init, fetch a fresh `{tunnel_url, access_token}` from Supabase
///      via [PrinterAccessCache].
///   2. v0.4: before navigation, set an `mg_token` cookie on the WebView
///      scoped to the tunnel host. The auth proxy on the Pi reads it on
///      every request the WebView makes (static assets + WebSocket upgrade),
///      verifies the EdDSA signature, and only then proxies to nginx /
///      Moonraker. On v0.3 Pis the cookie is set anyway but ignored.
///   3. Refresh the cookie at ~4 min (token TTL is 5 min) so an open
///      WebView session never falls off the cliff.
///   4. Load the LAN URL when one is cached (faster); fall back to tunnel
///      on error. Cookie scope is tunnel-host, so LAN requests don't carry
///      it — but LAN doesn't need it (nginx is unauth'd on LAN).
///   5. On 503 from /printer-access (Pi hasn't heartbeated yet, fresh
///      pairing) retry after a short delay. On other errors surface an
///      in-app overlay with a Retry button.
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
  bool    _usingLan  = false;
  String? _errorMsg;
  String? _tunnelUrl;
  Timer?  _retryTimer;
  Timer?  _cookieRefreshTimer;

  // Local copy of the printer name so the app bar reflects renames
  // immediately, without waiting for a dashboard rebuild.
  late String _displayName = widget.printer.name;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _cookieRefreshTimer?.cancel();
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
    final l = AppLocalizations.of(context);
    setState(() { _loading = true; _errorMsg = null; });
    try {
      final access = await PrinterAccessCache.instance.get(widget.printer.id);
      if (!mounted) return;
      _tunnelUrl = access.tunnelUrl;

      // v0.4: prime the EdDSA cookie before navigation so the auth proxy
      // accepts every WebView request (HTML, JS, XHR, WS upgrade). Schedule
      // a periodic refresh so a long-open session never sends an expired
      // token. Both no-ops on v0.3 Pis.
      await _setMgTokenCookie(access);
      _scheduleCookieRefresh();

      // Prefer the LAN URL when present — Mainsail loads dramatically
      // faster on direct LAN than through Cloudflare. v0.5.0: try the
      // mDNS-discovered address first (survives DHCP changes), then the
      // persisted one. Pre-flight a quick HEAD-style probe with a 2s
      // timeout: on cellular the phone has no route to RFC1918 addresses,
      // but the WebView would block silently (no `onWebResourceError`,
      // just a forever spinner) because it relies on the OS to time the
      // connect out. The probe gives us a fast decision and a clean
      // fall-through to the tunnel.
      final lanUrl = LanDiscoveryService.instance.lookup(widget.printer.id)
          ?? widget.printer.lanUrl;
      String? useUrl;
      if (lanUrl != null && await _isLanReachable(lanUrl)) {
        useUrl    = lanUrl;
        _usingLan = true;
      } else if (access.tunnelUrl != null) {
        useUrl    = access.tunnelUrl;
        _usingLan = false;
      }

      // Neither LAN reachable nor a tunnel URL yet — the printer was just
      // paired / is rebooting and remote isn't up. Show the same
      // "starting up" retry the 503 path uses instead of loading a null URL.
      if (useUrl == null) {
        if (!mounted) return;
        setState(() {
          _loading  = false;
          _errorMsg = l.printerStartingUpRetry(5);
        });
        _retryTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) _start();
        });
        return;
      }

      _initControllerIfNeeded();
      await _webController!.loadRequest(Uri.parse('$useUrl/'));
    } on PrinterUnavailableException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading  = false;
        _errorMsg = l.printerStartingUpRetry(e.retryAfter);
      });
      _retryTimer = Timer(Duration(seconds: e.retryAfter), () {
        if (mounted) _start();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _errorMsg = l.printerCouldNotReach('$e'); });
    }
  }

  Future<void> _showEditPrinterDialog() async {
    final l = AppLocalizations.of(context);
    final result = await showDialog<({String name, String? lanUrl})>(
      context: context,
      builder: (_) => _EditPrinterDialog(
        initialName:   _displayName,
        initialLanUrl: widget.printer.lanUrl,
      ),
    );
    if (result == null) return;
    final newName = result.name;
    if (newName.isNotEmpty && newName != _displayName) {
      await PrinterRegistry.instance.renamePrinter(widget.printer.id, newName);
      if (mounted) setState(() => _displayName = newName);
    }
    if (result.lanUrl != widget.printer.lanUrl) {
      await PrinterRegistry.instance
          .updateLanUrl(widget.printer.id, result.lanUrl);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.lanUrl == null
                ? l.printerAddressCleared
                : l.printerAddressUpdated),
          ),
        );
      }
    }
  }

  /// Force a fallback to the Cloudflare tunnel. Called from the Retry
  /// button on the error overlay (so a LAN load that fails surfaces a
  /// quick path to the tunnel).
  Future<void> _retryViaTunnel() async {
    if (_tunnelUrl == null) {
      _start();
      return;
    }
    setState(() { _loading = true; _errorMsg = null; _usingLan = false; });
    _initControllerIfNeeded();
    await _webController!.loadRequest(Uri.parse('$_tunnelUrl/'));
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
          final l = AppLocalizations.of(context);
          setState(() {
            _loading  = false;
            _errorMsg = l.printerTunnelUnreachable(err.description);
          });
        },
      ));
  }

  // ── v0.4: EdDSA cookie wiring for the WebView ─────────────────────────────
  //
  // The auth proxy on the Pi (v0.4+) requires every request to carry the
  // EdDSA access token. WebView-loaded static assets and WS upgrades can't
  // easily set an Authorization header, so we use a cookie scoped to the
  // tunnel host. The proxy reads `mg_token=<jwt>` from Cookie:, verifies
  // EdDSA, and proxies upstream.
  //
  // Scope decisions:
  //   - Domain = tunnel host exactly. We don't broaden to .trycloudflare.com
  //     because that would leak our token to anyone else's quick-tunnel
  //     subdomain the user might happen to visit in the same WebView.
  //   - Path = "/" — token applies to every resource on the host.
  //   - No explicit expiry — set as a session cookie, overwritten before
  //     the JWT expires by the refresh timer.

  Future<void> _setMgTokenCookie(PrinterAccess access) async {
    // No tunnel yet (fresh pair) → nothing to scope a cookie to. LAN
    // doesn't need it (nginx/Moonraker trust the subnet); the cookie gets
    // set on a later refresh once the tunnel comes up.
    if (access.tunnelUrl == null) return;
    final tunnel = Uri.tryParse(access.tunnelUrl!);
    if (tunnel == null || tunnel.host.isEmpty) return;
    try {
      await WebViewCookieManager().setCookie(WebViewCookie(
        name:   'mg_token',
        value:  access.accessToken,
        domain: tunnel.host,
        path:   '/',
      ));
    } catch (_) {
      // setCookie can throw on older WebView versions; fall through. The
      // WebView will eventually 401 and surface the error overlay.
    }
  }

  /// Fast LAN probe. Returns true iff `${lanUrl}/server/info` answers
  /// within 2 seconds. We hit Moonraker's own info endpoint rather than
  /// `/` because nginx serving Mainsail's index always 200s — Moonraker
  /// only answers when actually reachable, so a 200 here is also a
  /// liveness signal for the printer side. 401/403 still counts as
  /// reachable (we got an answer); only network failures and timeouts
  /// fall through to the tunnel.
  Future<bool> _isLanReachable(String lanUrl) async {
    try {
      final uri = Uri.parse('$lanUrl/server/info');
      final resp = await http
          .get(uri)
          .timeout(const Duration(seconds: 2));
      return resp.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  void _scheduleCookieRefresh() {
    _cookieRefreshTimer?.cancel();
    // Token TTL is 5 min; refresh at 4 to leave a safety margin for
    // clock skew + the WebView holding a stale cookie momentarily.
    _cookieRefreshTimer = Timer.periodic(const Duration(minutes: 4), (_) async {
      if (!mounted) return;
      try {
        final access = await PrinterAccessCache.instance.get(widget.printer.id);
        if (!mounted) return;
        await _setMgTokenCookie(access);
      } catch (_) {
        // Refresh failed — the WebView will eventually get a 401 and the
        // user can tap Retry. Don't disrupt the current view for a single
        // missed background refresh.
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Edit icon directly before the name (name + advanced address).
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              tooltip: l.printerEdit,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: _showEditPrinterDialog,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _displayName,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _usingLan ? l.printerLocalNetwork : l.printerTunnelVia,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: _usingLan ? Colors.green : Colors.orange,
                        ),
                  ),
                ],
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
                    l.printerUnreachable,
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
                    label: Text(l.commonRetry),
                  ),
                  if (_usingLan && _tunnelUrl != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _retryViaTunnel,
                      icon: const Icon(Icons.cloud_outlined),
                      label: Text(l.printerUseTunnel),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Edit-printer dialog ─────────────────────────────────────────────────────
//
// Name + an optional advanced "Printer address" override, for reverse-proxy /
// Docker setups where mDNS and the Pi-advertised address can't be reached.
// Wrapped in a StatefulWidget so the TextEditingControllers are owned by the
// dialog's State and disposed cleanly when the dialog is torn down. Disposing
// a controller from the calling code AFTER `await showDialog` resolves races
// the framework's own dispose pass and trips the `_dependents.isEmpty`
// assertion.

class _EditPrinterDialog extends StatefulWidget {
  final String  initialName;
  final String? initialLanUrl;
  const _EditPrinterDialog({required this.initialName, this.initialLanUrl});

  @override
  State<_EditPrinterDialog> createState() => _EditPrinterDialogState();
}

class _EditPrinterDialogState extends State<_EditPrinterDialog> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.initialName);
  final FocusNode _nameFocus = FocusNode();
  // Show the stored lanUrl without the scheme — the friendlier host:port
  // form people actually type.
  late final TextEditingController _addressController = TextEditingController(
    text: (widget.initialLanUrl ?? '').replaceFirst(RegExp(r'^https?://'), ''),
  );
  final FocusNode _addressFocus = FocusNode();
  String? _addressError;

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    _addressController.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  void _save() {
    final l       = AppLocalizations.of(context);
    final name    = _nameController.text.trim();
    final addrRaw = _addressController.text.trim();
    final lanUrl  = PrinterConfig.parseLanUrl(addrRaw);
    if (addrRaw.isNotEmpty && lanUrl == null) {
      setState(() => _addressError = l.printerAddressInvalid);
      return;
    }
    Navigator.pop(context, (name: name, lanUrl: lanUrl));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.printerEdit),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameController,
            focusNode: _nameFocus,
            autofocus: true,
            maxLength: 48,
            textCapitalization: TextCapitalization.words,
            onTap: () => showKeyboardFor(_nameFocus),
            decoration: InputDecoration(
              labelText: l.printerNameLabel,
              border: const OutlineInputBorder(),
              suffixIcon: ShowKeyboardButton(_nameFocus),
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _addressController,
            focusNode: _addressFocus,
            keyboardType: TextInputType.url,
            autocorrect: false,
            onTap: () => showKeyboardFor(_addressFocus),
            decoration: InputDecoration(
              labelText: l.printerAddressLabel,
              hintText: l.printerAddressHint,
              helperText: l.printerAddressHelper,
              helperMaxLines: 2,
              errorText: _addressError,
              border: const OutlineInputBorder(),
              suffixIcon: ShowKeyboardButton(_addressFocus),
            ),
            onChanged: (_) {
              if (_addressError != null) setState(() => _addressError = null);
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(l.commonSave),
        ),
      ],
    );
  }
}
