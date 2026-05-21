package com.moongate.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import androidx.core.app.NotificationCompat
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config
import java.io.StringReader

/**
 * Moongate's own VPN service — wraps WireGuard-Go so we never need
 * the separate Tailscale app on the phone.
 *
 * Notification strategy: IMPORTANCE_MIN channel → no banner, no sound,
 * icon hidden from status bar shade on most launchers. The OS-level key
 * icon in the system bar is unavoidable (Android security requirement).
 */
class MoongateVpnService : VpnService() {

    companion object {
        const val ACTION_CONNECT    = "com.moongate.app.VPN_CONNECT"
        const val ACTION_DISCONNECT = "com.moongate.app.VPN_DISCONNECT"
        const val EXTRA_WG_CONFIG   = "wg_config"

        private const val CHANNEL_ID  = "moongate_vpn"
        private const val NOTIF_ID    = 1001

        // Static handle used by VpnPlugin to track state
        @Volatile var isRunning = false
            private set
    }

    private var backend: GoBackend? = null
    private var tunnel: MoongateTunnel? = null

    override fun onCreate() {
        super.onCreate()
        createSilentNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_CONNECT -> {
                val config = intent.getStringExtra(EXTRA_WG_CONFIG)
                if (config != null) connect(config)
            }
            ACTION_DISCONNECT -> disconnect()
        }
        return START_STICKY
    }

    private fun connect(wgConfigText: String) {
        try {
            startForeground(NOTIF_ID, buildSilentNotification())

            val config = Config.parse(StringReader(wgConfigText))
            val tun = MoongateTunnel("moongate")
            tunnel = tun

            val b = GoBackend(this)
            backend = b
            b.startTunnel(tun, config)
            isRunning = true
        } catch (e: Exception) {
            disconnect()
        }
    }

    private fun disconnect() {
        try {
            tunnel?.let { backend?.stopTunnel(it) }
        } catch (_: Exception) {}
        backend = null
        tunnel = null
        isRunning = false
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        disconnect()
        super.onDestroy()
    }

    // ── Notification ─────────────────────────────────────────────────────────

    private fun createSilentNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Moongate VPN",
            NotificationManager.IMPORTANCE_MIN          // no sound, no banner
        ).apply {
            description      = "Moongate printer tunnel"
            setShowBadge(false)
            enableLights(false)
            enableVibration(false)
            setSound(null, null)
            lockscreenVisibility = Notification.VISIBILITY_SECRET
        }
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(channel)
    }

    private fun buildSilentNotification(): Notification {
        val mainIntent = packageManager
            .getLaunchIntentForPackage(packageName)
            ?.apply { flags = Intent.FLAG_ACTIVITY_SINGLE_TOP }
        val pi = PendingIntent.getActivity(
            this, 0, mainIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
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

// ── Tunnel identity ───────────────────────────────────────────────────────────

class MoongateTunnel(private val name: String) : Tunnel {
    @Volatile var state: Tunnel.State = Tunnel.State.DOWN
        private set

    override fun getName() = name

    override fun onStateChange(newState: Tunnel.State) {
        state = newState
    }
}
