package com.babyapp.baby_app

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Isolated device tests must never install a production APK as an update. */
object AppUpdates {
    fun register(context: Context, engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "nestling/updates")
            .setMethodCallHandler { _, result -> result.notImplemented() }
    }
}
