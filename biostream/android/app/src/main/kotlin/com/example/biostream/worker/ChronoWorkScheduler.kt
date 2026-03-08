package com.example.biostream.worker

import android.content.Context
import android.util.Log
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.time.Duration
import java.time.LocalDateTime
import java.util.concurrent.TimeUnit

object ChronoWorkScheduler {
    private const val TAG = "ChronoWorkScheduler"
    private const val WORK_NAME = "DailyHealthSyncWork"
    private const val ONE_TIME_WORK_NAME = "DebugHealthSyncWork"

    fun scheduleDailySync(context: Context) {
        val workManager = WorkManager.getInstance(context)

        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .setRequiresBatteryNotLow(true)
            .build()

        val initialDelay = calculateDelayUntil0100()

        val dailyWorkRequest = PeriodicWorkRequestBuilder<SyncHealthWorker>(
            24, TimeUnit.HOURS
        )
            .setConstraints(constraints)
            .setInitialDelay(initialDelay, TimeUnit.MILLISECONDS)
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 15, TimeUnit.MINUTES)
            .build()

        workManager.enqueueUniquePeriodicWork(
            WORK_NAME,
            ExistingPeriodicWorkPolicy.KEEP,
            dailyWorkRequest
        )
    }

    fun enqueueOneTimeSync(context: Context) {
        // 디버그 테스트는 가능한 즉시 실행되도록 배터리 조건을 제거
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val oneTimeRequest = OneTimeWorkRequestBuilder<SyncHealthWorker>()
            .setConstraints(constraints)
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 15, TimeUnit.MINUTES)
            .build()

        WorkManager.getInstance(context).enqueueUniqueWork(
            ONE_TIME_WORK_NAME,
            ExistingWorkPolicy.REPLACE,
            oneTimeRequest
        )

        Log.i(TAG, "One-time sync enqueued: id=${oneTimeRequest.id}")
    }

    private fun calculateDelayUntil0100(): Long {
        val now = LocalDateTime.now()
        var target = now.withHour(1).withMinute(0).withSecond(0).withNano(0)

        if (now.isAfter(target)) {
            target = target.plusDays(1)
        }

        return Duration.between(now, target).toMillis()
    }
}
