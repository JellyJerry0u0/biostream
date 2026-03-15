package com.example.biostream.worker

import android.content.Context
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ActiveCaloriesBurnedRecord
import androidx.health.connect.client.records.BloodGlucoseRecord
import androidx.health.connect.client.records.BodyFatRecord
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeightRecord
import androidx.health.connect.client.records.OxygenSaturationRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
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
import java.time.Instant
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
        private val REQUIRED_PERMISSIONS = setOf(
            HealthPermission.getReadPermission(StepsRecord::class),
            HealthPermission.getReadPermission(SleepSessionRecord::class),
        )
    }

    override suspend fun doWork(): Result {
        val healthConnectClient = HealthConnectClient.getOrCreate(applicationContext)

        return try {
            val granted = healthConnectClient.permissionController.getGrantedPermissions()
            if (!granted.containsAll(REQUIRED_PERMISSIONS)) {
                Log.w(TAG, "Health Connect permissions are not granted")
                return Result.failure()
            }

            val healthData = fetchYesterdayHealthData(healthConnectClient, granted)
            Log.i(TAG, "Sync payload => date=${healthData.date}, userId=${healthData.userId}, steps=${healthData.steps}, sleepMinutes=${healthData.sleepMinutes}, distanceMeters=${healthData.distanceMeters}, oxygenSaturation=${healthData.oxygenSaturation}, averageSpeedMps=${healthData.averageSpeedMps}, activeCaloriesKcal=${healthData.activeCaloriesKcal}, exerciseMinutes=${healthData.exerciseMinutes}, fitnessScore=${healthData.fitnessScore}, weightKg=${healthData.weightKg}, heightCm=${healthData.heightCm}, bodyFatPercentage=${healthData.bodyFatPercentage}, vo2Max=${healthData.vo2Max}, bloodGlucoseMgDl=${healthData.bloodGlucoseMgDl}")
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
        client: HealthConnectClient,
        grantedPermissions: Set<String>
    ): HealthDataDto {
        val userId = getStoredUserId()
        if (userId <= 0) {
            throw IllegalStateException("profile_user_id is missing. Please log in first.")
        }

        val zoneId = ZoneId.systemDefault()
        val yesterdayDate = LocalDate.now(zoneId).minusDays(1)
        val startOfYesterday = yesterdayDate.atStartOfDay(zoneId).toInstant()
        val startOfToday = yesterdayDate.plusDays(1).atStartOfDay(zoneId).toInstant()
        val sleepQueryStart = startOfYesterday.minus(Duration.ofDays(1))

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
                timeRangeFilter = TimeRangeFilter.between(sleepQueryStart, startOfToday)
            )
        ).records

        val sleepMinutes = sleepRecords.sumOf {
            val overlapStart = if (it.startTime.isAfter(startOfYesterday)) it.startTime else startOfYesterday
            val overlapEnd = if (it.endTime.isBefore(startOfToday)) it.endTime else startOfToday
            if (overlapEnd.isAfter(overlapStart)) {
                Duration.between(overlapStart, overlapEnd).toMinutes().coerceAtLeast(0)
            } else {
                0L
            }
        }

        val canReadDistance = grantedPermissions.contains(HealthPermission.getReadPermission(DistanceRecord::class))
        val canReadOxygen = grantedPermissions.contains(HealthPermission.getReadPermission(OxygenSaturationRecord::class))
        val canReadActiveCalories = grantedPermissions.contains(HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class))
        val canReadTotalCalories = grantedPermissions.contains(HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class))
        val canReadExercise = grantedPermissions.contains(HealthPermission.getReadPermission(ExerciseSessionRecord::class))
        val canReadWeight = grantedPermissions.contains(HealthPermission.getReadPermission(WeightRecord::class))
        val canReadHeight = grantedPermissions.contains(HealthPermission.getReadPermission(HeightRecord::class))
        val canReadBodyFat = grantedPermissions.contains(HealthPermission.getReadPermission(BodyFatRecord::class))
        val canReadVo2 = grantedPermissions.contains(HealthPermission.getReadPermission(Vo2MaxRecord::class))
        val canReadGlucose = grantedPermissions.contains(HealthPermission.getReadPermission(BloodGlucoseRecord::class))

        val distanceMeters = if (canReadDistance) client.aggregate(
            AggregateRequest(
                metrics = setOf(DistanceRecord.DISTANCE_TOTAL),
                timeRangeFilter = TimeRangeFilter.between(startOfYesterday, startOfToday)
            )
        )[DistanceRecord.DISTANCE_TOTAL]?.inMeters ?: 0.0 else 0.0

        val oxygenRecords = if (canReadOxygen) client.readRecords(
            ReadRecordsRequest(
                recordType = OxygenSaturationRecord::class,
                timeRangeFilter = TimeRangeFilter.between(startOfYesterday, startOfToday)
            )
        ).records else emptyList()
        val oxygenSaturation = if (oxygenRecords.isNotEmpty()) {
            oxygenRecords.map { it.percentage.value }.average()
        } else {
            0.0
        }

        val activeCaloriesKcal = if (canReadActiveCalories) client.aggregate(
            AggregateRequest(
                metrics = setOf(ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL),
                timeRangeFilter = TimeRangeFilter.between(startOfYesterday, startOfToday)
            )
        )[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]?.inKilocalories ?: 0.0 else 0.0

        val totalCaloriesKcal = if (canReadTotalCalories) client.aggregate(
            AggregateRequest(
                metrics = setOf(TotalCaloriesBurnedRecord.ENERGY_TOTAL),
                timeRangeFilter = TimeRangeFilter.between(startOfYesterday, startOfToday)
            )
        )[TotalCaloriesBurnedRecord.ENERGY_TOTAL]?.inKilocalories ?: 0.0 else 0.0

        val resolvedActiveCaloriesKcal = if (totalCaloriesKcal > 0.0) {
            totalCaloriesKcal
        } else if (activeCaloriesKcal > 0.0) {
            activeCaloriesKcal
        } else {
            0.0
        }

        val exerciseRecords = if (canReadExercise) client.readRecords(
            ReadRecordsRequest(
                recordType = ExerciseSessionRecord::class,
                timeRangeFilter = TimeRangeFilter.between(startOfYesterday, startOfToday)
            )
        ).records else emptyList()
        val exerciseMinutes = exerciseRecords.sumOf {
            Duration.between(it.startTime, it.endTime).toMinutes().coerceAtLeast(0)
        }

        // 체중은 해당 날짜 기록이 없을 수 있어 전체 기록 중 최신값을 우선 사용
        val weightRecords = if (canReadWeight) client.readRecords(
            ReadRecordsRequest(
                recordType = WeightRecord::class,
                timeRangeFilter = TimeRangeFilter.before(Instant.now())
            )
        ).records else emptyList()
        val weightKg = weightRecords.maxByOrNull { it.time }?.weight?.inKilograms ?: 0.0

        // 신장도 최신값 1건을 사용 (cm)
        val heightRecords = if (canReadHeight) client.readRecords(
            ReadRecordsRequest(
                recordType = HeightRecord::class,
                timeRangeFilter = TimeRangeFilter.before(Instant.now())
            )
        ).records else emptyList()
        val heightCm = (heightRecords.maxByOrNull { it.time }?.height?.inMeters ?: 0.0) * 100.0

        // 일부 소스는 DistanceRecord를 저장하지 않아 steps 기반 거리 추정을 fallback으로 사용
        val estimatedStepLengthMeters = if (heightCm > 0.0) heightCm * 0.00415 else 0.78
        val resolvedDistanceMeters = if (distanceMeters > 0.0) {
            distanceMeters
        } else {
            steps * estimatedStepLengthMeters
        }

        val averageSpeedMps = if (exerciseMinutes > 0L) {
            resolvedDistanceMeters / (exerciseMinutes * 60.0)
        } else {
            0.0
        }

        val bodyFatRecords = if (canReadBodyFat) client.readRecords(
            ReadRecordsRequest(
                recordType = BodyFatRecord::class,
                timeRangeFilter = TimeRangeFilter.between(startOfYesterday, startOfToday)
            )
        ).records else emptyList()
        val bodyFatPercentage = bodyFatRecords.maxByOrNull { it.time }?.percentage?.value ?: 0.0

        val vo2Records = if (canReadVo2) client.readRecords(
            ReadRecordsRequest(
                recordType = Vo2MaxRecord::class,
                timeRangeFilter = TimeRangeFilter.between(startOfYesterday, startOfToday)
            )
        ).records else emptyList()
        val vo2Max = vo2Records.maxByOrNull { it.time }?.vo2MillilitersPerMinuteKilogram ?: 0.0

        val bloodGlucoseRecords = if (canReadGlucose) client.readRecords(
            ReadRecordsRequest(
                recordType = BloodGlucoseRecord::class,
                timeRangeFilter = TimeRangeFilter.between(startOfYesterday, startOfToday)
            )
        ).records else emptyList()
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
            distanceMeters = resolvedDistanceMeters,
            oxygenSaturation = oxygenSaturation,
            averageSpeedMps = averageSpeedMps,
            activeCaloriesKcal = resolvedActiveCaloriesKcal,
            exerciseMinutes = exerciseMinutes,
            fitnessScore = fitnessScore,
            weightKg = weightKg,
            heightCm = heightCm,
            bodyFatPercentage = bodyFatPercentage,
            vo2Max = vo2Max,
            bloodGlucoseMgDl = bloodGlucoseMgDl,
        )
    }

    private fun getStoredUserId(): Int {
        val prefs = applicationContext.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val raw = prefs.all[KEY_PROFILE_USER_ID] ?: return -1
        return when (raw) {
            is Int -> raw
            is Long -> raw.toInt()
            is Float -> raw.toInt()
            is Double -> raw.toInt()
            is String -> raw.toIntOrNull() ?: -1
            else -> -1
        }
    }
}
