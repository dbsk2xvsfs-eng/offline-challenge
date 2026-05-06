package com.petrknejzlik.offlinetimer

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "offline_challenge/tracking"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startTrackingService" -> {
                    val intent = Intent(this, ScreenTrackingService::class.java)

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }

                    result.success(true)
                }

                "stopTrackingService" -> {
                    val intent = Intent(this, ScreenTrackingService::class.java)
                    stopService(intent)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }
}