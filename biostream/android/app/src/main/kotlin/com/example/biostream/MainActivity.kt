package com.example.biostream

import android.os.Bundle
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.lifecycle.lifecycleScope
import com.example.biostream.network.HealthDataDto
import io.flutter.embedding.android.FlutterFragmentActivity
import kotlinx.coroutines.launch
import java.time.Duration
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter

class MainActivity : FlutterFragmentActivity() {

	companion object {
		private const val TAG = "MainActivity"
	}

	private val healthConnectClient by lazy { HealthConnectClient.getOrCreate(this) }

	private val permissions = setOf(
		HealthPermission.getReadPermission(StepsRecord::class),
		HealthPermission.getReadPermission(SleepSessionRecord::class)
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

	private suspend fun checkAndRequestPermissions() {
		val granted = healthConnectClient.permissionController.getGrantedPermissions()
		if (!granted.containsAll(permissions)) {
			requestPermissions.launch(permissions)
			return
		}
		onHealthPermissionsGranted()
	}

	private fun onHealthPermissionsGranted() {
		lifecycleScope.launch {
			val healthData = fetchYesterdayHealthData(healthConnectClient)
			Log.d(TAG, "Yesterday health data: $healthData")
		}
	}

	private fun onHealthPermissionsDenied() {
		Log.w(TAG, "Health Connect permissions denied")
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
			sleepMinutes = totalSleepMinutes
		)
	}
}
