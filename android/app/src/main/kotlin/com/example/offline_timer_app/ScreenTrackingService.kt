package com.example.offline_timer_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import org.json.JSONObject
import java.time.Instant
import org.json.JSONArray

class ScreenTrackingService : Service() {

    private val channelId = "offline_tracking_channel"
    private val notificationId = 1001

    private lateinit var prefs: SharedPreferences

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            try {
                when (intent.action) {
                    Intent.ACTION_SCREEN_OFF -> handleScreenOff()
                 Intent.ACTION_SCREEN_ON -> handleScreenOn()
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    override fun onCreate() {
        super.onCreate()

        prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

        createNotificationChannel()

        startForeground(
            notificationId,
            buildNotification()
        )

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
        }

        registerReceiver(screenReceiver, filter)
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(screenReceiver)
        } catch (_: Exception) {
        }

        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun handleScreenOff() {
        val alreadyStarted = prefs.getString("flutter.screen_off_started_at", null)
        if (!alreadyStarted.isNullOrEmpty()) return

        prefs.edit()
            .putString("flutter.screen_off_started_at", Instant.now().toString())
            .apply()
    }

    private fun handleScreenOn() {
        val rawStart = prefs.getString("flutter.screen_off_started_at", null)
        if (rawStart.isNullOrEmpty()) return

        prefs.edit()
            .remove("flutter.screen_off_started_at")
            .apply()

        val startedAt = try {
            Instant.parse(rawStart)
        } catch (_: Exception) {
            return
        }

        val now = Instant.now()
        val durationMinutes = java.time.Duration.between(startedAt, now).toMinutes().toInt()

        if (durationMinutes < 1) return

        saveSession(rawStart, durationMinutes)
    }

    private fun saveSession(startedAtIso: String, durationMinutes: Int) {
    try {
        val key = "flutter.native_session_history"

        val raw = prefs.getString(key, "[]") ?: "[]"
        val array = JSONArray(raw)

        val json = JSONObject().apply {
            put("startedAt", startedAtIso)
            put("durationMinutes", durationMinutes)
        }

        array.put(json)

        prefs.edit()
            .putString(key, array.toString())
            .apply()

    } catch (e: Exception) {
        e.printStackTrace()
    }
}

    private fun buildNotification(): Notification {
        return NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("Offline Challenge")
            .setContentText("Collecting screen-off offline time")
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            channelId,
            "Offline tracking",
            NotificationManager.IMPORTANCE_LOW
        )

        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(channel)
    }
}