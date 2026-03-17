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
import androidx.lifecycle.lifecycleScope
import com.example.biostream.network.HealthDataDto
import com.example.biostream.worker.ChronoWorkScheduler
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.launch
import java.time.Duration
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

	private val permissions = setOf(
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

	private val requestPermissions = registerForActivityResult(
		PermissionController.createRequestPermissionResultContract()
	) { granted ->
		if (granted.containsAll(permissions)) {
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
						ChronoWorkScheduler.enqueueOneTimeSync(applicationContext)
						result.success("queued")
					}
					else -> result.notImplemented()
				}
			}
	}

	private suspend fun checkAndRequestPermissions() {
		val granted = healthConnectClient.permissionController.getGrantedPermissions()
		if (!granted.containsAll(permissions)) {
			requestPermissions.launch(permissions)
			return
		}
		onHealthPermissionsGranted()
	}

	private fun onHealthPermissionsGranted() {
		ChronoWorkScheduler.scheduleDailySync(this)
		lifecycleScope.launch {
			val healthData = fetchYesterdayHealthData(healthConnectClient)
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

	private suspend fun fetchYesterdayHealthData(
		healthConnectClient: HealthConnectClient
	): HealthDataDto {
		val zoneId = ZoneId.systemDefault()
		val yesterdayDate = LocalDate.now(zoneId).minusDays(1)
		val startOfYesterday = yesterdayDate.atStartOfDay(zoneId).toInstant()
		val startOfToday = yesterdayDate.plusDays(1).atStartOfDay(zoneId).toInstant()

		val stepResponse = healthConnectClient.aggregate(
			AggregateRequest(
				metrics = setOf(StepsRecord.COUNT_TOTAL),
				timeRangeFilter = TimeRangeFilter.between(startOfYesterday, startOfToday)
			)
		)
		val stepCount = stepResponse[StepsRecord.COUNT_TOTAL] ?: 0L

		val sleepSessions = healthConnectClient.readRecords(
			ReadRecordsRequest(
				recordType = SleepSessionRecord::class,
				timeRangeFilter = TimeRangeFilter.between(startOfYesterday, startOfToday)
			)
		).records

		val totalSleepMinutes = sleepSessions.sumOf {
			Duration.between(it.startTime, it.endTime).toMinutes().coerceAtLeast(0)
		}

		return HealthDataDto(
			date = yesterdayDate.format(DateTimeFormatter.ISO_LOCAL_DATE),
			steps = stepCount,
			sleepMinutes = totalSleepMinutes,
			userId = getStoredUserId()
		)
	}

	private fun getStoredUserId(): Int {
		val prefs = getSharedPreferences(FLUTTER_PREFS, MODE_PRIVATE)
		return prefs.getInt(KEY_PROFILE_USER_ID, -1)
	}
}
