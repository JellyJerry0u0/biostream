package com.example.biostream.worker

import android.content.Context
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.BloodGlucoseRecord
import androidx.health.connect.client.records.BodyFatRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.NutritionRecord
import androidx.health.connect.client.records.OxygenSaturationRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.Vo2MaxRecord
import androidx.health.connect.client.records.WeightRecord
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
                HealthPermission.getReadPermission(SleepSessionRecord::class),
                HealthPermission.getReadPermission(DistanceRecord::class),
                HealthPermission.getReadPermission(OxygenSaturationRecord::class),
                HealthPermission.getReadPermission(NutritionRecord::class),
                HealthPermission.getReadPermission(ExerciseSessionRecord::class),
                HealthPermission.getReadPermission(WeightRecord::class),
                HealthPermission.getReadPermission(BodyFatRecord::class),
                HealthPermission.getReadPermission(Vo2MaxRecord::class),
                HealthPermission.getReadPermission(BloodGlucoseRecord::class)
            )
            val granted = healthConnectClient.permissionController.getGrantedPermissions()
            if (!granted.containsAll(permissions)) {
                Log.w(TAG, "Health Connect permissions are not granted")
                return Result.failure()
            }

            val healthData = fetchYesterdayHealthData(healthConnectClient)
            Log.i(TAG, "Sync payload => date=${healthData.date}, userId=${healthData.userId}, steps=${healthData.steps}, sleepMinutes=${healthData.sleepMinutes}, distanceMeters=${healthData.distanceMeters}, oxygenSaturation=${healthData.oxygenSaturation}, averageSpeedMps=${healthData.averageSpeedMps}, nutritionCaloriesKcal=${healthData.nutritionCaloriesKcal}, exerciseMinutes=${healthData.exerciseMinutes}, fitnessScore=${healthData.fitnessScore}, weightKg=${healthData.weightKg}, bodyFatPercentage=${healthData.bodyFatPercentage}, vo2Max=${healthData.vo2Max}, bloodGlucoseMgDl=${healthData.bloodGlucoseMgDl}")
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

        val distanceMeters = client.aggregate(
            AggregateRequest(
                metrics = setOf(DistanceRecord.DISTANCE_TOTAL),
                timeRangeFilter = TimeRangeFilter.between(startOfYesterday, startOfToday)
            )
        )[DistanceRecord.DISTANCE_TOTAL]?.inMeters ?: 0.0

        val oxygenRecords = client.readRecords(
            ReadRecordsRequest(
                recordType = OxygenSaturationRecord::class,
                timeRangeFilter = TimeRangeFilter.between(startOfYesterday, startOfToday)
            )
        ).records
        val oxygenSaturation = if (oxygenRecords.isNotEmpty()) {
            oxygenRecords.map { it.percentage.value }.average()
        } else {
            0.0
        }

        val nutritionRecords = client.readRecords(
            ReadRecordsRequest(
                recordType = NutritionRecord::class,
                timeRangeFilter = TimeRangeFilter.between(startOfYesterday, startOfToday)
            )
        ).records
        val nutritionCaloriesKcal = nutritionRecords.sumOf {
            it.energy?.inKilocalories ?: 0.0
        }

        val exerciseRecords = client.readRecords(
            ReadRecordsRequest(
                recordType = ExerciseSessionRecord::class,
                timeRangeFilter = TimeRangeFilter.between(startOfYesterday, startOfToday)
            )
        ).records
        val exerciseMinutes = exerciseRecords.sumOf {
            Duration.between(it.startTime, it.endTime).toMinutes().coerceAtLeast(0)
        }

        val averageSpeedMps = if (exerciseMinutes > 0L) {
            distanceMeters / (exerciseMinutes * 60.0)
        } else {
            0.0
        }

        val weightRecords = client.readRecords(
            ReadRecordsRequest(
                recordType = WeightRecord::class,
                timeRangeFilter = TimeRangeFilter.between(startOfYesterday, startOfToday)
            )
        ).records
        val weightKg = weightRecords.maxByOrNull { it.time }?.weight?.inKilograms ?: 0.0

        val bodyFatRecords = client.readRecords(
            ReadRecordsRequest(
                recordType = BodyFatRecord::class,
                timeRangeFilter = TimeRangeFilter.between(startOfYesterday, startOfToday)
            )
        ).records
        val bodyFatPercentage = bodyFatRecords.maxByOrNull { it.time }?.percentage?.value ?: 0.0

        val vo2Records = client.readRecords(
            ReadRecordsRequest(
                recordType = Vo2MaxRecord::class,
                timeRangeFilter = TimeRangeFilter.between(startOfYesterday, startOfToday)
            )
        ).records
        val vo2Max = vo2Records.maxByOrNull { it.time }?.vo2MillilitersPerMinuteKilogram ?: 0.0

        val bloodGlucoseRecords = client.readRecords(
            ReadRecordsRequest(
                recordType = BloodGlucoseRecord::class,
                timeRangeFilter = TimeRangeFilter.between(startOfYesterday, startOfToday)
            )
        ).records
        val bloodGlucoseMgDl = bloodGlucoseRecords.maxByOrNull { it.time }?.level?.inMilligramsPerDeciliter ?: 0.0

        val fitnessScore = when {
            vo2Max > 0.0 -> vo2Max
            else -> (exerciseMinutes / 6.0).coerceIn(0.0, 100.0)
        }

        return HealthDataDto(
            date = yesterdayDate.format(DateTimeFormatter.ISO_LOCAL_DATE),
            steps = steps,
            sleepMinutes = sleepMinutes,
            userId = userId,
            distanceMeters = distanceMeters,
            oxygenSaturation = oxygenSaturation,
            averageSpeedMps = averageSpeedMps,
            nutritionCaloriesKcal = nutritionCaloriesKcal,
            exerciseMinutes = exerciseMinutes,
            fitnessScore = fitnessScore,
            weightKg = weightKg,
            bodyFatPercentage = bodyFatPercentage,
            vo2Max = vo2Max,
            bloodGlucoseMgDl = bloodGlucoseMgDl,
        )
    }

    private fun getStoredUserId(): Int {
        val prefs = applicationContext.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        return prefs.getInt(KEY_PROFILE_USER_ID, -1)
    }
}
