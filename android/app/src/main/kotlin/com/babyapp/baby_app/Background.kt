package com.babyapp.baby_app

import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/// One Flutter engine per process, shared by [MainActivity] and [SyncService],
/// plus the `nestling/background` channel the Dart side uses to control them.
object Background {
    const val ENGINE_ID = "main"
    private const val CHANNEL = "nestling/background"
    // Pre-rename prefs file name kept so background sync stays enabled.
    private const val PREFS = "babylog_background"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_CAMERA = "camera_monitoring"

    private var wakeLock: PowerManager.WakeLock? = null

    /// [headless]: started by the service without a screen. Dart restores saved
    /// camera monitoring, but leaves foreground UI timers and video stopped.
    fun engine(context: Context, headless: Boolean = false): FlutterEngine {
        FlutterEngineCache.getInstance().get(ENGINE_ID)?.let { return it }
        val app = context.applicationContext
        val engine = FlutterEngine(app)
        AppUpdates.register(app, engine)
        FeedingTimer.register(app, engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    setEnabled(app, true)
                    startService(app)
                    result.success(null)
                }
                "stop" -> {
                    setEnabled(app, false)
                    if (!isEnabled(app)) app.stopService(Intent(app, SyncService::class.java))
                    result.success(null)
                }
                "cameraMonitoring" -> {
                    val on = call.arguments == true
                    app.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_CAMERA, on).apply()
                    if (isEnabled(app)) {
                        if (!startService(app)) {
                            app.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_CAMERA, false).apply()
                            result.error("background_unavailable", "Android refused camera monitoring", null)
                        } else result.success(null)
                    } else {
                        app.stopService(Intent(app, SyncService::class.java))
                        result.success(null)
                    }
                }
                "leaveLockScreen" -> {
                    MainActivity.current?.get()?.let { it.runOnUiThread { it.setLockScreen(false) } }
                    result.success(null)
                }
                "isBatteryExempt" -> {
                    val pm = app.getSystemService(Context.POWER_SERVICE) as PowerManager
                    result.success(pm.isIgnoringBatteryOptimizations(app.packageName))
                }
                "requestBatteryExempt" -> {
                    requestBatteryExempt(app)
                    result.success(null)
                }
                "keepAwake" -> {
                    keepAwake(app, (call.arguments as? Number)?.toLong() ?: 30_000L)
                    result.success(null)
                }
                "deviceName" -> result.success(deviceName(app))
                "multicastLock" -> {
                    setMulticast(app, call.arguments == true)
                    result.success(null)
                }
                "releaseAwake" -> {
                    wakeLock?.takeIf { it.isHeld }?.release()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault(),
            if (headless) listOf("--headless") else null,
        )
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
        return engine
    }

    fun isCameraEnabled(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_CAMERA, false)

    fun isEnabled(context: Context) = isCameraEnabled(context) ||
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_ENABLED, false)

    private fun setEnabled(context: Context, on: Boolean) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_ENABLED, on).apply()

    fun startService(context: Context): Boolean {
        val intent = Intent(context, SyncService::class.java)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            return true
        } catch (e: Exception) {
            // Android can refuse to start it from the background; it is started
            // again next time the app opens.
            android.util.Log.w("Nestling", "Could not start sync service", e)
            return false
        }
    }

    /// The name the user gave this phone in Android settings, else e.g. "Samsung SM-S911B".
    private fun deviceName(context: Context): String {
        val resolver = context.contentResolver
        val named = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
                Settings.Global.getString(resolver, Settings.Global.DEVICE_NAME)
            } else {
                null
            } ?: Settings.Secure.getString(resolver, "bluetooth_name")
        } catch (e: Exception) {
            null
        }
        if (!named.isNullOrBlank()) return named.trim()
        val maker = Build.MANUFACTURER.replaceFirstChar { it.uppercase() }
        return if (Build.MODEL.startsWith(maker, ignoreCase = true)) Build.MODEL else "$maker ${Build.MODEL}"
    }

    @SuppressLint("BatteryLife")
    private fun requestBatteryExempt(context: Context) {
        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS, Uri.parse("package:${context.packageName}"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            context.startActivity(intent)
        } catch (e: Exception) {
            context.startActivity(
                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
    }

    private fun keepAwake(context: Context, millis: Long) {
        val lock = wakeLock ?: (context.getSystemService(Context.POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "Nestling:sync")
            .apply { setReferenceCounted(false) }
            .also { wakeLock = it }
        lock.acquire(millis)
    }

    private var multicastLock: android.net.wifi.WifiManager.MulticastLock? = null

    /// Android drops incoming multicast (mDNS) unless an app holds this.
    /// Held only while looking for the Nanit camera.
    private fun setMulticast(context: Context, on: Boolean) {
        if (on) {
            if (multicastLock?.isHeld == true) return
            val wifi = context.getSystemService(Context.WIFI_SERVICE) as android.net.wifi.WifiManager
            multicastLock = wifi.createMulticastLock("Nestling:nanit").apply {
                setReferenceCounted(false)
                acquire()
            }
        } else {
            multicastLock?.takeIf { it.isHeld }?.release()
            multicastLock = null
        }
    }
}
