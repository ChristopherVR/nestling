package com.babyapp.baby_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/// Foreground service that keeps the process (and the shared Flutter engine
/// running sync and camera polling) alive without an activity. Camera monitoring
/// holds a separate CPU wake lock only while the user has enabled it. Partner
/// sync alone retains its short, per-request wake lock behavior.
class SyncService : Service() {
    private var cameraWake: PowerManager.WakeLock? = null
    override fun onCreate() {
        super.onCreate()
        startInForeground()
        // Started at boot or after the app was swiped away: bring Dart back up.
        Background.engine(this, headless = true)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startInForeground()
        if (Background.isCameraEnabled(this)) {
            if (cameraWake?.isHeld != true) {
                cameraWake = (getSystemService(Context.POWER_SERVICE) as PowerManager)
                    .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Nestling:cameraMonitoring")
                    .apply { setReferenceCounted(false); acquire() }
            }
        } else {
            cameraWake?.takeIf { it.isHeld }?.release()
            cameraWake = null
        }
        return START_STICKY
    }

    override fun onDestroy() {
        cameraWake?.takeIf { it.isHeld }?.release()
        cameraWake = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startInForeground() {
        val channelId = "background_sync"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Background sync", NotificationManager.IMPORTANCE_MIN)
            channel.description = "Shown while Nestling keeps your devices in sync"
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java), PendingIntent.FLAG_IMMUTABLE
        )
        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) Notification.Builder(this, channelId)
        else Notification.Builder(this)
        val notification = builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Nestling")
            .setContentText(if (Background.isCameraEnabled(this)) "Camera sound and cry monitoring enabled · keep home Wi-Fi connected" else "Sharing your log over Wi-Fi")
            .setOngoing(true)
            .setContentIntent(open)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    companion object {
        // Away from the ids flutter_local_notifications uses for reminders.
        private const val NOTIFICATION_ID = 4242
    }
}

/// Restarts background sync after a reboot or app update, if it was on.
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (Background.isEnabled(context)) Background.startService(context)
    }
}
