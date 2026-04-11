package com.example.biostream.worker

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.example.biostream.receiver.UvOutdoorActionReceiver
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter

class UvOutdoorPromptWorker(
    appContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    companion object {
        private const val TAG = "UvOutdoorPromptWorker"
        private const val CHANNEL_ID = "outdoor_uv_prompt_channel"
        private const val CHANNEL_NAME = "Outdoor UV Prompt"
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val KEY_LAST_PROMPT_AT_MS = "flutter.uv_last_prompt_epoch_ms_bg"
        private const val KEY_DAILY_PROMPT_DATE = "flutter.uv_daily_prompt_date_bg"
        private const val KEY_DAILY_PROMPT_COUNT = "flutter.uv_daily_prompt_count_bg"

        private const val STEP_THRESHOLD = 2500L
        private const val DAILY_LIMIT = 3
        private const val COOLDOWN_MS = 2L * 60L * 60L * 1000L
    }

    override suspend fun doWork(): Result {
        return try {
            val now = LocalDateTime.now()
            if (now.hour < 8 || now.hour > 18) {
                return Result.success()
            }

            val prefs = applicationContext.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            val today = LocalDate.now().format(DateTimeFormatter.ISO_LOCAL_DATE)

            val savedDate = prefs.getString(KEY_DAILY_PROMPT_DATE, null)
            var promptCount = prefs.getInt(KEY_DAILY_PROMPT_COUNT, 0)
            if (savedDate != today) {
                prefs.edit()
                    .putString(KEY_DAILY_PROMPT_DATE, today)
                    .putInt(KEY_DAILY_PROMPT_COUNT, 0)
                    .apply()
                promptCount = 0
            }

            if (promptCount >= DAILY_LIMIT) {
                return Result.success()
            }

            val lastPromptAt = prefs.getLong(KEY_LAST_PROMPT_AT_MS, 0L)
            if (lastPromptAt > 0L && (System.currentTimeMillis() - lastPromptAt) < COOLDOWN_MS) {
                return Result.success()
            }

            val client = HealthConnectClient.getOrCreate(applicationContext)
            val permission = HealthPermission.getReadPermission(StepsRecord::class)
            val granted = client.permissionController.getGrantedPermissions()
            if (!granted.contains(permission)) {
                return Result.success()
            }

            val zoneId = ZoneId.systemDefault()
            val start = LocalDate.now(zoneId).atStartOfDay(zoneId).toInstant()
            val end = Instant.now()
            val steps = client.aggregate(
                AggregateRequest(
                    metrics = setOf(StepsRecord.COUNT_TOTAL),
                    timeRangeFilter = TimeRangeFilter.between(start, end)
                )
            )[StepsRecord.COUNT_TOTAL] ?: 0L

            if (steps < STEP_THRESHOLD) {
                return Result.success()
            }

            if (!NotificationManagerCompat.from(applicationContext).areNotificationsEnabled()) {
                return Result.success()
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                ActivityCompat.checkSelfPermission(
                    applicationContext,
                    Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                return Result.success()
            }

            createChannelIfNeeded()
            showOutdoorPromptNotification(today, steps.toInt())

            prefs.edit()
                .putLong(KEY_LAST_PROMPT_AT_MS, System.currentTimeMillis())
                .putString(KEY_DAILY_PROMPT_DATE, today)
                .putInt(KEY_DAILY_PROMPT_COUNT, promptCount + 1)
                .apply()

            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to process UV outdoor prompt", e)
            Result.retry()
        }
    }

    private fun createChannelIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "걸음수 기반 야외 여부 확인 알림 채널"
        }
        manager.createNotificationChannel(channel)
    }

    private fun showOutdoorPromptNotification(date: String, steps: Int) {
        val yesIntent = Intent(applicationContext, UvOutdoorActionReceiver::class.java).apply {
            action = UvOutdoorActionReceiver.ACTION_YES
            putExtra(UvOutdoorActionReceiver.EXTRA_DATE, date)
            putExtra(UvOutdoorActionReceiver.EXTRA_STEPS, steps)
        }
        val noIntent = Intent(applicationContext, UvOutdoorActionReceiver::class.java).apply {
            action = UvOutdoorActionReceiver.ACTION_NO
            putExtra(UvOutdoorActionReceiver.EXTRA_DATE, date)
            putExtra(UvOutdoorActionReceiver.EXTRA_STEPS, steps)
        }

        val yesPendingIntent = PendingIntent.getBroadcast(
            applicationContext,
            (date.hashCode() * 31) + 1,
            yesIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val noPendingIntent = PendingIntent.getBroadcast(
            applicationContext,
            (date.hashCode() * 31) + 2,
            noIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("야외 활동 확인")
            .setContentText("지금 야외에 계신가요?")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .addAction(0, "예", yesPendingIntent)
            .addAction(0, "아니오", noPendingIntent)
            .build()

        NotificationManagerCompat.from(applicationContext)
            .notify(date.hashCode(), notification)
    }
}
