package com.example.biostream.receiver

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import com.example.biostream.network.OutdoorCheckResponseDto
import com.example.biostream.network.RetrofitClient
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class UvOutdoorActionReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "UvOutdoorActionReceiver"
        const val ACTION_YES = "com.example.biostream.action.UV_OUTDOOR_YES"
        const val ACTION_NO = "com.example.biostream.action.UV_OUTDOOR_NO"
        const val EXTRA_DATE = "extra_date"
        const val EXTRA_STEPS = "extra_steps"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val pendingResult = goAsync()
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val date = intent.getStringExtra(EXTRA_DATE)?.trim().orEmpty()
                if (date.isEmpty()) {
                    Log.w(TAG, "Missing date in notification action payload")
                    return@launch
                }
                val steps = intent.getIntExtra(EXTRA_STEPS, 0)
                val answer = when (intent.action) {
                    ACTION_YES -> "yes"
                    ACTION_NO -> "no"
                    else -> "unknown"
                }

                val response = RetrofitClient
                    .getChronoLensService(context.applicationContext)
                    .submitOutdoorCheckResponse(
                        OutdoorCheckResponseDto(
                            date = date,
                            answer = answer,
                            stepsSnapshot = steps,
                        )
                    )

                if (!response.isSuccessful) {
                    Log.w(TAG, "Failed to submit outdoor response: ${response.code()}")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to submit outdoor response", e)
            } finally {
                pendingResult.finish()
            }
        }
    }
}
