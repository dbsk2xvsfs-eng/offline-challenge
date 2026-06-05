package com.petrknejzlik.offlinetimer

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
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import com.google.firebase.Timestamp
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions

class ScreenTrackingService : Service() {

    private val channelId = "offline_tracking_channel"

    private val summaryChannelId = "offline_summary_channel"
    private val notificationId = 1001

    private lateinit var prefs: SharedPreferences

    private val handler = Handler(Looper.getMainLooper())

    private val notificationChecker = object : Runnable {
        override fun run() {
            checkSummaryNotifications()
            handler.postDelayed(this, 60_000)
        }
    }

    private lateinit var firestore: FirebaseFirestore
    private val leaderboardSyncIntervalMs = 15 * 60 * 1000L

    private val leaderboardSyncer = object : Runnable {
        override fun run() {
            syncLeaderboardFromService()
            handler.postDelayed(this, leaderboardSyncIntervalMs)
        }
    }   

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

        firestore = FirebaseFirestore.getInstance()
        handler.post(leaderboardSyncer)

        startForeground(
            notificationId,
            buildNotification()
        )

        val filter = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
        }

        registerReceiver(screenReceiver, filter)
        handler.post(notificationChecker)
    }

    override fun onDestroy() {
        try {
            unregisterReceiver(screenReceiver)
        } catch (_: Exception) {
        }

        handler.removeCallbacks(notificationChecker)

        handler.removeCallbacks(leaderboardSyncer)

        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun handleScreenOff() {

        android.util.Log.d("OFFLINE", "SCREEN OFF TRIGGERED")

        val alreadyStarted = prefs.getString("flutter.screen_off_started_at", null)
        if (!alreadyStarted.isNullOrEmpty()) return

        prefs.edit()
            .putString("flutter.screen_off_started_at", Instant.now().toString())
            .apply()
    }

    private fun handleScreenOn() {

        checkSummaryNotifications()

        val rawStart = prefs.getString("flutter.screen_off_started_at", null)
        if (rawStart.isNullOrEmpty()) return

        val startedAt = try {
            Instant.parse(rawStart)
        } catch (_: Exception) {
            prefs.edit().remove("flutter.screen_off_started_at").apply()
            return
        }

        // smažeme hned (aby se neuložilo víckrát)
        prefs.edit().remove("flutter.screen_off_started_at").apply()

        val now = Instant.now()

        val startLocal = startedAt.atZone(java.time.ZoneId.systemDefault())
        val endLocal = now.atZone(java.time.ZoneId.systemDefault())

        // 🔥 pokud je stejný den → jednoduché
        if (startLocal.toLocalDate() == endLocal.toLocalDate()) {

            val duration =
                java.time.Duration.between(startLocal, endLocal).toMinutes().toInt()

            if (duration >= 1) {
                saveSession(startedAt.toString(), duration)
            }
            return
        }

        // 🔥 ROZDĚLENÍ PŘES PŮLNOC

        // 1️⃣ část – do konce dne
        val endOfDay = startLocal.toLocalDate()
            .atTime(23, 59, 59)
            .atZone(startLocal.zone)

        val firstPart =
            java.time.Duration.between(startLocal, endOfDay).toMinutes().toInt()

        if (firstPart >= 1) {
            saveSession(startLocal.toInstant().toString(), firstPart)
        }

        // 2️⃣ část – od půlnoci do teď
        val startOfNextDay = endLocal.toLocalDate()
            .atStartOfDay(startLocal.zone)

        val secondPart =
            java.time.Duration.between(startOfNextDay, endLocal).toMinutes().toInt()

        if (secondPart >= 1) {
            saveSession(startOfNextDay.toInstant().toString(), secondPart)
        }
    }

    private fun syncLeaderboardFromService() {
        try {
            android.util.Log.d("LEADERBOARD_SYNC", "SYNC STARTED")

            val userId = prefs.getString("flutter.leaderboard_user_id", null)
            android.util.Log.d("LEADERBOARD_SYNC", "USER ID = $userId")
            if (userId == null) return

            val rawProfile = prefs.getString("flutter.user_profile", null) ?: return
            val profile = JSONObject(rawProfile)

            val showInRankings = profile.optBoolean("showInRankings", true)
            if (!showInRankings) return

            val nickname = profile.optString("nickname", "Anonymous")
            val country = profile.optString("country", "UN")
            val cityRaw = profile.optString("city", "unknown")

            val data = hashMapOf<String, Any>(
                "nickname" to if (nickname.trim().isEmpty()) "Anonymous" else nickname.trim(),
                "country" to if (country.trim().isEmpty()) "UN" else country.trim().uppercase(),
                "city" to normalizeCity(cityRaw),
                "cityDisplay" to if (cityRaw.trim().isEmpty()) "unknown" else cityRaw.trim(),

                "dayMinutes" to totalMinutesForTodayIncludingCurrent(),
                "weekMinutes" to totalMinutesForCurrentWeekIncludingCurrent(),
                "monthMinutes" to totalMinutesForCurrentMonthIncludingCurrent(),
                "allMinutes" to totalMinutesAllIncludingCurrent(),

                "lastStatsSyncAt" to Timestamp.now(),
                "updatedAt" to Timestamp.now(),
                "syncSource" to "android_service"
            )

            firestore.collection("leaderboard")
                .document(userId)
                .set(data, SetOptions.merge())
                .addOnSuccessListener {
                    android.util.Log.d("LEADERBOARD_SYNC", "UPLOAD OK")
                }
                .addOnFailureListener { e ->
                    android.util.Log.e("LEADERBOARD_SYNC", "UPLOAD FAIL", e)
                }

        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun currentRunningSessionMinutes(): Pair<Instant, Int>? {
        val rawStart = prefs.getString("flutter.screen_off_started_at", null) ?: return null

        val startedAt = try {
            Instant.parse(rawStart)
        } catch (_: Exception) {
            return null
        }

        val minutes = java.time.Duration.between(startedAt, Instant.now()).toMinutes().toInt()
        if (minutes < 1) return null

        return Pair(startedAt, minutes)
    }

    private fun totalMinutesAllIncludingCurrent(): Int {
        var total = totalMinutesAll()
        val running = currentRunningSessionMinutes()
        if (running != null) total += running.second
        return total
    }

    private fun totalMinutesForTodayIncludingCurrent(): Int {
        var total = totalMinutesForToday()
        val running = currentRunningSessionMinutes()

        if (running != null) {
            val date = running.first.atZone(java.time.ZoneId.systemDefault()).toLocalDate()
            if (date == LocalDate.now()) {
                total += running.second
            }
        }

        return total
    }

    private fun totalMinutesForCurrentWeekIncludingCurrent(): Int {
        var total = totalMinutesForCurrentWeek()
        val running = currentRunningSessionMinutes()

        if (running != null) {
            val date = running.first.atZone(java.time.ZoneId.systemDefault()).toLocalDate()
            val today = LocalDate.now()
            val weekStart = today.minusDays((today.dayOfWeek.value - 1).toLong())

            if (!date.isBefore(weekStart)) {
                total += running.second
            }
        }

        return total
    }

    private fun totalMinutesForCurrentMonthIncludingCurrent(): Int {
        var total = totalMinutesForCurrentMonth()
        val running = currentRunningSessionMinutes()

        if (running != null) {
            val date = running.first.atZone(java.time.ZoneId.systemDefault()).toLocalDate()
            val today = LocalDate.now()
            val monthStart = LocalDate.of(today.year, today.month, 1)

            if (!date.isBefore(monthStart)) {
                total += running.second
            }
        }

        return total
    }

    private fun totalMinutesAll(): Int {
        val sessions = loadNativeSessions()
        var total = 0

        for (i in 0 until sessions.length()) {
            val item = sessions.getJSONObject(i)
            total += item.optInt("durationMinutes", 0)
        }

        return total
    }

    private fun normalizeCity(value: String): String {
        return value
            .trim()
            .lowercase()
            .replace("á", "a")
            .replace("č", "c")
            .replace("ď", "d")
            .replace("é", "e")
            .replace("ě", "e")
            .replace("í", "i")
            .replace("ň", "n")
            .replace("ó", "o")
            .replace("ř", "r")
            .replace("š", "s")
            .replace("ť", "t")
            .replace("ú", "u")
            .replace("ů", "u")
            .replace("ý", "y")
            .replace("ž", "z")
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

    private fun checkSummaryNotifications() {
        try {
            val raw = prefs.getString("flutter.notification_settings", null) ?: return

            val json = JSONObject(raw)

            val now = LocalDateTime.now()
            val today = LocalDate.now()

            val dailyEnabled = json.optBoolean("dailyEnabled", false)
            val dailyHour = json.optInt("dailyHour", 21)
            val dailyMinute = json.optInt("dailyMinute", 0)

            val nowMinutes = now.hour * 60 + now.minute
            val dailyTargetMinutes = dailyHour * 60 + dailyMinute

            if (
                dailyEnabled &&
                nowMinutes >= dailyTargetMinutes &&
                shouldSendOnce("daily", today.toString())
            ) {
                val todayMinutes = totalMinutesForToday()

                showSummaryNotification(
                    id = 2001,
                    title = "Daily offline summary",
                    message = "Today: ${formatMinutes(todayMinutes)} offline 🔥"
                )
                markSent("daily", today.toString())
            }

            val weeklyEnabled = json.optBoolean("weeklyEnabled", false)
            val weeklyDay = json.optInt("weeklyDay", 7)
            val normalizedWeeklyDay = if (weeklyDay == 0) 7 else weeklyDay
            val weeklyHour = json.optInt("weeklyHour", 18)
            val weeklyMinute = json.optInt("weeklyMinute", 0)

            val weeklyTargetMinutes = weeklyHour * 60 + weeklyMinute

            if (
                weeklyEnabled &&
                now.dayOfWeek.value == normalizedWeeklyDay &&
                nowMinutes >= weeklyTargetMinutes &&
                shouldSendOnce("weekly", today.toString())
            ) {
                val weekMinutes = totalMinutesForCurrentWeek()

                showSummaryNotification(
                    id = 2002,
                    title = "Weekly offline summary",
                    message = "This week: ${formatMinutes(weekMinutes)} offline 🏆"
                )
                markSent("weekly", today.toString())
            }

            val monthlyEnabled = json.optBoolean("monthlyEnabled", false)
            val monthlyDay = json.optInt("monthlyDay", 1)
            val monthlyHour = json.optInt("monthlyHour", 20)
            val monthlyMinute = json.optInt("monthlyMinute", 0)

            val monthlyTargetMinutes = monthlyHour * 60 + monthlyMinute

            if (
                monthlyEnabled &&
                now.dayOfMonth == monthlyDay &&
                nowMinutes >= monthlyTargetMinutes &&
                shouldSendOnce("monthly", "${today.year}-${today.monthValue}")
            ) {
                val monthMinutes = totalMinutesForCurrentMonth()

                showSummaryNotification(
                    id = 2003,
                    title = "Monthly offline summary",
                    message = "This month: ${formatMinutes(monthMinutes)} offline 🚀"
                )
                markSent("monthly", "${today.year}-${today.monthValue}")
            }

        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun shouldSendOnce(type: String, key: String): Boolean {
        val last = prefs.getString("flutter.notification_last_sent_$type", null)
        return last != key
    }

    private fun markSent(type: String, key: String) {
        prefs.edit()
            .putString("flutter.notification_last_sent_$type", key)
            .apply()
    }

    private fun showSummaryNotification(
        id: Int,
        title: String,
        message: String
    ) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val notification = NotificationCompat.Builder(this, summaryChannelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setAutoCancel(false)
            .build()

        manager.notify(id, notification)
    }


    private fun formatMinutes(minutes: Int): String {
        val hours = minutes / 60
        val mins = minutes % 60

        return when {
            hours == 0 -> "$mins min"
            mins == 0 -> "$hours h"
            else -> "$hours h $mins min"
        }
    }

    private fun loadNativeSessions(): JSONArray {
        val raw = prefs.getString("flutter.native_session_history", "[]") ?: "[]"
        return JSONArray(raw)
    }

    private fun totalMinutesForToday(): Int {
        val sessions = loadNativeSessions()
        val today = LocalDate.now()
        var total = 0

        for (i in 0 until sessions.length()) {
            val item = sessions.getJSONObject(i)
            val startedAt = Instant.parse(item.getString("startedAt"))
            val date = startedAt.atZone(java.time.ZoneId.systemDefault()).toLocalDate()

            if (date == today) {
                total += item.optInt("durationMinutes", 0)
            }
        }

        return total
    }

    private fun totalMinutesForCurrentWeek(): Int {
        val sessions = loadNativeSessions()
        val today = LocalDate.now()
        val weekStart = today.minusDays((today.dayOfWeek.value - 1).toLong())
        var total = 0

        for (i in 0 until sessions.length()) {
            val item = sessions.getJSONObject(i)
            val startedAt = Instant.parse(item.getString("startedAt"))
            val date = startedAt.atZone(java.time.ZoneId.systemDefault()).toLocalDate()

            if (!date.isBefore(weekStart)) {
                total += item.optInt("durationMinutes", 0)
            }
        }

        return total
    }

    private fun totalMinutesForCurrentMonth(): Int {
        val sessions = loadNativeSessions()
        val today = LocalDate.now()
        val monthStart = LocalDate.of(today.year, today.month, 1)
        var total = 0

        for (i in 0 until sessions.length()) {
            val item = sessions.getJSONObject(i)
            val startedAt = Instant.parse(item.getString("startedAt"))
            val date = startedAt.atZone(java.time.ZoneId.systemDefault()).toLocalDate()

            if (!date.isBefore(monthStart)) {
                total += item.optInt("durationMinutes", 0)
            }
        }

        return total
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

        val trackingChannel = NotificationChannel(
            channelId,
            "Offline tracking",
            NotificationManager.IMPORTANCE_LOW
        )

        val summaryChannel = NotificationChannel(
            summaryChannelId,
            "Offline summaries",
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Daily, weekly and monthly Offline Challenge summaries"
            enableVibration(true)
            enableLights(true)
        }

        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(trackingChannel)
        manager.createNotificationChannel(summaryChannel)
    }
}