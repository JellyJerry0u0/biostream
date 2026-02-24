package com.example.biostream.worker

import android.content.Context
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.example.biostream.network.HealthDataDto
import com.example.biostream.network.RetrofitClient
import java.time.Duration
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter

class SyncHealthWorker(
    appContext: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(appContext, workerParams) {

    companion object {
        private const val TAG = "SyncHealthWorker"
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val KEY_PROFILE_USER_ID = "flutter.profile_user_id"
    }

    override suspend fun doWork(): Result {
        val healthConnectClient = HealthConnectClient.getOrCreate(applicationContext)

        return try {
            val permissions = setOf(
                HealthPermission.getReadPermission(StepsRecord::class),
                HealthPermission.getReadPermission(SleepSessionRecord::class)
            )
            val granted = healthConnectClient.permissionController.getGrantedPermissions()
            if (!granted.containsAll(permissions)) {
                Log.w(TAG, "Health Connect permissions are not granted")
                return Result.failure()
            }

            val healthData = fetchYesterdayHealthData(healthConnectClient)
            val response = RetrofitClient
                .getChronoLensService(applicationContext)
                .syncHealthData(healthData)

            if (response.isSuccessful) {
                Log.d(TAG, "새벽 데이터 동기화 성공")
                Result.success()
            } else {
                Log.e(TAG, "서버 응답 실패: ${response.code()}")
                Result.retry()
            }
        } catch (e: Exception) {
            Log.e(TAG, "데이터 동기화 중 에러 발생", e)
            Result.retry()
        }
    }

    private suspend fun fetchYesterdayHealthData(
        client: HealthConnectClient
    ): HealthDataDto {
        val userId = getStoredUserId()
        if (userId <= 0) {
            throw IllegalStateException("profile_user_id is missing. Please log in first.")
        }

        val zoneId = ZoneId.systemDefault()
        val yesterdayDate = LocalDate.now(zoneId).minusDays(1)
        val startOfYesterday = yesterdayDate.atStartOfDay(zoneId).toInstant()
        val startOfToday = yesterdayDate.plusDays(1).atStartOfDay(zoneId).toInstant()

        val stepResponse = client.aggregate(
            AggregateRequest(
                metrics = setOf(StepsRecord.COUNT_TOTAL),
                timeRangeFilter = TimeRangeFilter.between(startOfYesterday, startOfToday)
            )
        )
        val steps = stepResponse[StepsRecord.COUNT_TOTAL] ?: 0L

        val sleepRecords = client.readRecords(
            ReadRecordsRequest(
                recordType = SleepSessionRecord::class,
                timeRangeFilter = TimeRangeFilter.between(startOfYesterday, startOfToday)
            )
        ).records

        val sleepMinutes = sleepRecords.sumOf {
            Duration.between(it.startTime, it.endTime).toMinutes().coerceAtLeast(0)
        }

        return HealthDataDto(
            date = yesterdayDate.format(DateTimeFormatter.ISO_LOCAL_DATE),
            steps = steps,
            sleepMinutes = sleepMinutes,
            userId = userId
        )
    }

    private fun getStoredUserId(): Int {
        val prefs = applicationContext.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        return prefs.getInt(KEY_PROFILE_USER_ID, -1)
    }
}
