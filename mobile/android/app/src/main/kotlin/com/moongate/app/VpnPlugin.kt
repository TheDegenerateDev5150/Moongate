package com.moongate.app

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter ↔ native bridge for Moongate's WireGuard VPN.
 *
 * Flutter calls:
 *   connect(config: String)   — WireGuard INI config text
 *   disconnect()
 *   isConnected() → Boolean
 *
 * Native → Flutter events (via invokeMethod):
 *   onConnected
 *   onDisconnected
 */
class VpnPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private var activity: Activity? = null
    private var pendingConfig: String? = null
    private var pendingResult: MethodChannel.Result? = null

    companion object {
        private const val CHANNEL = "com.moongate.app/vpn"
        private const val VPN_PERMISSION_REQUEST = 1001
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connect" -> {
                val config = call.argument<String>("config") ?: run {
                    result.error("INVALID_ARG", "config is required", null)
                    return
                }
                requestVpnPermission(config, result)
            }
            "disconnect" -> {
                stopVpnService()
                channel.invokeMethod("onDisconnected", null)
                result.success(null)
            }
            "isConnected" -> {
                result.success(MoongateVpnService.isRunning)
            }
            else -> result.notImplemented()
        }
    }

    private fun requestVpnPermission(config: String, result: MethodChannel.Result) {
        val act = activity ?: run {
            result.error("NO_ACTIVITY", "No activity", null)
            return
        }
        val intent = VpnService.prepare(act)
        if (intent != null) {
            pendingConfig = config
            pendingResult = result
            act.startActivityForResult(intent, VPN_PERMISSION_REQUEST)
        } else {
            startVpnService(config)
            channel.invokeMethod("onConnected", null)
            result.success(null)
        }
    }

    private fun startVpnService(config: String) {
        val ctx = activity ?: return
        val intent = Intent(ctx, MoongateVpnService::class.java).apply {
            action = MoongateVpnService.ACTION_CONNECT
            putExtra(MoongateVpnService.EXTRA_WG_CONFIG, config)
        }
        ctx.startForegroundService(intent)
    }

    private fun stopVpnService() {
        val ctx = activity ?: return
        val intent = Intent(ctx, MoongateVpnService::class.java).apply {
            action = MoongateVpnService.ACTION_DISCONNECT
        }
        ctx.startService(intent)
    }

    // ActivityAware ───────────────────────────────────────────────────────────

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener { requestCode, resultCode, _ ->
            if (requestCode == VPN_PERMISSION_REQUEST) {
                val cfg = pendingConfig
                val res = pendingResult
                pendingConfig = null
                pendingResult = null
                if (resultCode == Activity.RESULT_OK && cfg != null) {
                    startVpnService(cfg)
                    channel.invokeMethod("onConnected", null)
                    res?.success(null)
                } else {
                    res?.error("PERMISSION_DENIED", "VPN permission denied", null)
                }
                true
            } else false
        }
    }

    override fun onDetachedFromActivity() { activity = null }
    override fun onReattachedToActivityForConfigChanges(b: ActivityPluginBinding) = onAttachedToActivity(b)
    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()
}
