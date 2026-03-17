package com.biostream.app

import android.os.Bundle
import android.util.Log
import android.widget.Toast
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
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
import androidx.health.connect.client.records.Vo2MaxRecord
import androidx.health.connect.client.records.WeightRecord
import androidx.lifecycle.lifecycleScope
import com.example.biostream.network.HealthDataDto
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import com.example.biostream.network.RetrofitClient
import com.example.biostream.worker.ChronoWorkScheduler
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.launch
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter

class MainActivity : FlutterFragmentActivity() {

	companion object {
		private const val TAG = "MainActivity"
		private const val DEV_CHANNEL = "com.example.biostream/dev"
		private const val FLUTTER_PREFS = "FlutterSharedPreferences"
		private const val KEY_PROFILE_USER_ID = "flutter.profile_user_id"
	}

	private val healthConnectClient by lazy { HealthConnectClient.getOrCreate(this) }

	private val requiredPermissions = setOf(
		HealthPermission.getReadPermission(StepsRecord::class),
		HealthPermission.getReadPermission(SleepSessionRecord::class),
	)

	private val permissions = setOf(
		HealthPermission.getReadPermission(StepsRecord::class),
		HealthPermission.getReadPermission(SleepSessionRecord::class),
		HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
		HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class),
		HealthPermission.getReadPermission(DistanceRecord::class),
		HealthPermission.getReadPermission(OxygenSaturationRecord::class),
		HealthPermission.getReadPermission(ExerciseSessionRecord::class),
		HealthPermission.getReadPermission(WeightRecord::class),
		HealthPermission.getReadPermission(HeightRecord::class),
		HealthPermission.getReadPermission(BodyFatRecord::class),
		HealthPermission.getReadPermission(Vo2MaxRecord::class),
		HealthPermission.getReadPermission(BloodGlucoseRecord::class)
	)

	private val requestPermissions = registerForActivityResult(
		PermissionController.createRequestPermissionResultContract()
	) { granted ->
		if (granted.containsAll(requiredPermissions)) {
			onHealthPermissionsGranted()
		} else {
			onHealthPermissionsDenied()
		}
	}

	override fun onCreate(savedInstanceState: Bundle?) {
		super.onCreate(savedInstanceState)
		lifecycleScope.launch {
			checkAndRequestPermissions()
		}
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEV_CHANNEL)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"enqueueOneTimeHealthSync" -> {
						Log.i(TAG, "MethodChannel enqueueOneTimeHealthSync invoked")
						ChronoWorkScheduler.enqueueOneTimeSync(applicationContext)
						Log.i(TAG, "MethodChannel enqueueOneTimeHealthSync queued")
						result.success("queued")
					}
					"runImmediateHealthSync" -> {
						Log.i(TAG, "MethodChannel runImmediateHealthSync invoked")
						lifecycleScope.launch {
							try {
								val granted = healthConnectClient.permissionController.getGrantedPermissions()
								if (!granted.containsAll(requiredPermissions)) {
									result.error("PERMISSION_DENIED", "Health Connect 권한이 모두 허용되지 않았습니다.", null)
									return@launch
								}

								val payload = fetchHealthData(healthConnectClient, daysAgo = 1, grantedPermissions = granted)
								Log.i(TAG, "Immediate sync payload => $payload")

								val response = RetrofitClient
									.getChronoLensService(applicationContext)
									.syncHealthData(payload)

								if (response.isSuccessful) {
									Log.i(TAG, "Immediate sync success")
									result.success(
										hashMapOf(
											"ok" to true,
											"steps" to payload.steps,
											"sleepMinutes" to payload.sleepMinutes,
											"date" to payload.date,
											"statusCode" to response.code(),
										)
									)
								} else {
									Log.e(TAG, "Immediate sync failed: ${response.code()}")
									result.error("HTTP_ERROR", "서버 응답 실패: ${response.code()}", null)
								}
							} catch (e: Exception) {
								Log.e(TAG, "Immediate sync error", e)
								result.error("SYNC_ERROR", e.message ?: "즉시 동기화 실패", null)
							}
						}
					}
					"runImmediateHealthSyncToday" -> {
						Log.i(TAG, "MethodChannel runImmediateHealthSyncToday invoked")
						lifecycleScope.launch {
							try {
								val granted = healthConnectClient.permissionController.getGrantedPermissions()
								if (!granted.containsAll(requiredPermissions)) {
									result.error("PERMISSION_DENIED", "Health Connect 권한이 모두 허용되지 않았습니다.", null)
									return@launch
								}

								val payload = fetchHealthData(healthConnectClient, daysAgo = 0, grantedPermissions = granted)
								Log.i(TAG, "Immediate TODAY sync payload => $payload")

								val response = RetrofitClient
									.getChronoLensService(applicationContext)
									.syncHealthData(payload)

								if (response.isSuccessful) {
									result.success(
										hashMapOf(
											"ok" to true,
											"date" to payload.date,
											"statusCode" to response.code(),
										)
									)
								} else {
									result.error("HTTP_ERROR", "서버 응답 실패: ${response.code()}", null)
								}
							} catch (e: Exception) {
								Log.e(TAG, "Immediate TODAY sync error", e)
								result.error("SYNC_ERROR", e.message ?: "오늘 데이터 즉시 동기화 실패", null)
							}
						}
					}
					else -> result.notImplemented()
				}
			}
	}

	private suspend fun checkAndRequestPermissions() {
		val granted = healthConnectClient.permissionController.getGrantedPermissions()
		if (!granted.containsAll(requiredPermissions)) {
			requestPermissions.launch(permissions)
			return
		}
		onHealthPermissionsGranted()
	}

	private fun onHealthPermissionsGranted() {
		ChronoWorkScheduler.scheduleDailySync(this)
		lifecycleScope.launch {
			val granted = healthConnectClient.permissionController.getGrantedPermissions()
			val healthData = fetchHealthData(healthConnectClient, daysAgo = 1, grantedPermissions = granted)
			Log.d(TAG, "Yesterday health data: $healthData")
		}
	}

	private fun onHealthPermissionsDenied() {
		Log.w(TAG, "Health Connect permissions denied")
		Toast.makeText(
			this,
			"Health Connect 권한이 필요합니다. 권한을 허용해 주세요.",
			Toast.LENGTH_LONG
		).show()
	}

	private suspend fun fetchHealthData(
		healthConnectClient: HealthConnectClient,
		daysAgo: Long,
		grantedPermissions: Set<String>
	): HealthDataDto {
		val zoneId = ZoneId.systemDefault()
		val targetDate = LocalDate.now(zoneId).minusDays(daysAgo)
		val start = targetDate.atStartOfDay(zoneId).toInstant()
		val end = targetDate.plusDays(1).atStartOfDay(zoneId).toInstant()
		val sleepQueryStart = start.minus(Duration.ofDays(1))

		val stepCount = healthConnectClient.aggregate(
			AggregateRequest(
				metrics = setOf(StepsRecord.COUNT_TOTAL),
				timeRangeFilter = TimeRangeFilter.between(start, end)
			)
		)[StepsRecord.COUNT_TOTAL] ?: 0L

		val sleepSessions = healthConnectClient.readRecords(
			ReadRecordsRequest(
				recordType = SleepSessionRecord::class,
				timeRangeFilter = TimeRangeFilter.between(sleepQueryStart, end)
			)
		).records
		val totalSleepMinutes = sleepSessions.sumOf {
			val overlapStart = if (it.startTime.isAfter(start)) it.startTime else start
			val overlapEnd = if (it.endTime.isBefore(end)) it.endTime else end
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

		val distanceMeters = if (canReadDistance) healthConnectClient.aggregate(
			AggregateRequest(
				metrics = setOf(DistanceRecord.DISTANCE_TOTAL),
				timeRangeFilter = TimeRangeFilter.between(start, end)
			)
		)[DistanceRecord.DISTANCE_TOTAL]?.inMeters ?: 0.0 else 0.0

		val oxygenRecords = if (canReadOxygen) healthConnectClient.readRecords(
			ReadRecordsRequest(
				recordType = OxygenSaturationRecord::class,
				timeRangeFilter = TimeRangeFilter.between(start, end)
			)
		).records else emptyList()
		val oxygenSaturation = if (oxygenRecords.isNotEmpty())
			oxygenRecords.map { it.percentage.value }.average() else 0.0

		val activeCaloriesKcal = if (canReadActiveCalories) healthConnectClient.aggregate(
			AggregateRequest(
				metrics = setOf(ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL),
				timeRangeFilter = TimeRangeFilter.between(start, end)
			)
		)[ActiveCaloriesBurnedRecord.ACTIVE_CALORIES_TOTAL]?.inKilocalories ?: 0.0 else 0.0

		val totalCaloriesKcal = if (canReadTotalCalories) healthConnectClient.aggregate(
			AggregateRequest(
				metrics = setOf(TotalCaloriesBurnedRecord.ENERGY_TOTAL),
				timeRangeFilter = TimeRangeFilter.between(start, end)
			)
		)[TotalCaloriesBurnedRecord.ENERGY_TOTAL]?.inKilocalories ?: 0.0 else 0.0
		val resolvedActiveCaloriesKcal = if (totalCaloriesKcal > 0.0) {
			totalCaloriesKcal
		} else if (activeCaloriesKcal > 0.0) {
			activeCaloriesKcal
		} else {
			0.0
		}

		val exerciseRecords = if (canReadExercise) healthConnectClient.readRecords(
			ReadRecordsRequest(
				recordType = ExerciseSessionRecord::class,
				timeRangeFilter = TimeRangeFilter.between(start, end)
			)
		).records else emptyList()
		val exerciseMinutes = exerciseRecords.sumOf {
			Duration.between(it.startTime, it.endTime).toMinutes().coerceAtLeast(0)
		}

		// 체중·신장은 해당 날짜 기록이 없을 수 있으므로 전체 기록 중 최신값 사용
		val weightKg = if (canReadWeight) healthConnectClient.readRecords(
			ReadRecordsRequest(
				recordType = WeightRecord::class,
				timeRangeFilter = TimeRangeFilter.before(Instant.now())
			)
		).records.maxByOrNull { it.time }?.weight?.inKilograms ?: 0.0 else 0.0

		val heightCm = (if (canReadHeight) healthConnectClient.readRecords(
			ReadRecordsRequest(
				recordType = HeightRecord::class,
				timeRangeFilter = TimeRangeFilter.before(Instant.now())
			)
		).records.maxByOrNull { it.time }?.height?.inMeters ?: 0.0 else 0.0) * 100.0

		// 일부 기기/소스는 DistanceRecord를 저장하지 않으므로 걸음수 기반 추정 거리 fallback 적용
		val estimatedStepLengthMeters = if (heightCm > 0.0) heightCm * 0.00415 else 0.78
		val resolvedDistanceMeters = if (distanceMeters > 0.0) {
			distanceMeters
		} else {
			stepCount * estimatedStepLengthMeters
		}

		val averageSpeedMps = if (exerciseMinutes > 0L)
			resolvedDistanceMeters / (exerciseMinutes * 60.0) else 0.0

		val bodyFatPercentage = if (canReadBodyFat) healthConnectClient.readRecords(
			ReadRecordsRequest(
				recordType = BodyFatRecord::class,
				timeRangeFilter = TimeRangeFilter.between(start, end)
			)
		).records.maxByOrNull { it.time }?.percentage?.value ?: 0.0 else 0.0

		val vo2Max = if (canReadVo2) healthConnectClient.readRecords(
			ReadRecordsRequest(
				recordType = Vo2MaxRecord::class,
				timeRangeFilter = TimeRangeFilter.between(start, end)
			)
		).records.maxByOrNull { it.time }?.vo2MillilitersPerMinuteKilogram ?: 0.0 else 0.0

		val bloodGlucoseMgDl = if (canReadGlucose) healthConnectClient.readRecords(
			ReadRecordsRequest(
				recordType = BloodGlucoseRecord::class,
				timeRangeFilter = TimeRangeFilter.between(start, end)
			)
		).records.maxByOrNull { it.time }?.level?.inMilligramsPerDeciliter ?: 0.0 else 0.0

		val fitnessScore = if (vo2Max > 0.0) vo2Max
			else (exerciseMinutes / 6.0).coerceIn(0.0, 100.0)

		return HealthDataDto(
			date = targetDate.format(DateTimeFormatter.ISO_LOCAL_DATE),
			steps = stepCount,
			sleepMinutes = totalSleepMinutes,
			userId = getStoredUserId(),
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
		val prefs = getSharedPreferences(FLUTTER_PREFS, MODE_PRIVATE)
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
