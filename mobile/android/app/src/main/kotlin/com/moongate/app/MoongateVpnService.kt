package com.moongate.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import androidx.core.app.NotificationCompat

/**
 * Moongate VPN service.
 *
 * Phase 1 (current): stub — parses the WireGuard config and holds state, but
 * does not yet establish a real tunnel (the app uses Tailscale for routing).
 *
 * Phase 2: native WireGuard-Go will be bundled as a compiled .so via a local
 * Gradle module (wireguard-android is not published to Maven Central and must
 * be compiled from Go source).
 *
 * Notification strategy: IMPORTANCE_MIN channel → no banner, no sound.
 * The OS key icon in the system bar is unavoidable on Android.
 */
class MoongateVpnService : VpnService() {

    companion object {
        const val ACTION_CONNECT    = "com.moongate.app.VPN_CONNECT"
        const val ACTION_DISCONNECT = "com.moongate.app.VPN_DISCONNECT"
        const val EXTRA_WG_CONFIG   = "wg_config"

        private const val CHANNEL_ID = "moongate_vpn"
        private const val NOTIF_ID   = 1001

        /** Observed by VpnPlugin to report isConnected() to Flutter. */
        @Volatile var isRunning = false
            private set
    }

    // The WireGuard config text received from the Moongate server.
    // Stored for Phase 2 when we hand it to the Go backend.
    private var pendingConfig: String? = null

    override fun onCreate() {
        super.onCreate()
        createSilentNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CONNECT    -> connect(intent.getStringExtra(EXTRA_WG_CONFIG))
            ACTION_DISCONNECT -> disconnect()
        }
        return START_STICKY
    }

    private fun connect(wgConfigText: String?) {
        if (wgConfigText == null) return
        pendingConfig = wgConfigText
        isRunning     = true

        // Show the minimal foreground notification (required by Android).
        // We do NOT call builder.establish() yet — no TUN device is created.
        // In Phase 2 this is where GoBackend.startTunnel() will be called.
        startForeground(NOTIF_ID, buildSilentNotification())
    }

    private fun disconnect() {
        isRunning     = false
        pendingConfig = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }

    // ── Silent notification ───────────────────────────────────────────────────

    private fun createSilentNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Moongate VPN",
            NotificationManager.IMPORTANCE_MIN   // no sound, no pop-up banner
        ).apply {
            description          = "Moongate printer tunnel"
            setShowBadge(false)
            enableLights(false)
            enableVibration(false)
            setSound(null, null)
            lockscreenVisibility = Notification.VISIBILITY_SECRET
        }
        (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .createNotificationChannel(channel)
    }

    private fun buildSilentNotification(): Notification {
        val mainIntent = packageManager
            .getLaunchIntentForPackage(packageName)
            ?.apply { flags = Intent.FLAG_ACTIVITY_SINGLE_TOP }
        val pi = PendingIntent.getActivity(
            this, 0, mainIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("Moongate")
            .setContentText("Printer tunnel active")
            .setContentIntent(pi)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .setVisibility(NotificationCompat.VISIBILITY_SECRET)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_DEFERRED)
            .build()
    }
}
