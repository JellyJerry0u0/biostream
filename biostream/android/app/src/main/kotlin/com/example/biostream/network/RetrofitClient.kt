package com.example.biostream.network

import android.content.Context
import android.util.Log
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory

object RetrofitClient {
    private const val TAG = "RetrofitClient"
    private const val DEFAULT_BASE_URL = "http://10.0.2.2:8080/"
    private const val FLUTTER_PREFS = "FlutterSharedPreferences"
    private const val KEY_BASE_ORIGIN = "flutter.api_base_origin"

    @Volatile
    private var cachedBaseUrl: String? = null

    @Volatile
    private var cachedService: ChronoLensService? = null

    fun getChronoLensService(context: Context): ChronoLensService {
        val baseUrl = resolveBaseUrl(context)
        val existingService = cachedService
        if (existingService != null && cachedBaseUrl == baseUrl) {
            return existingService
        }

        synchronized(this) {
            val doubleChecked = cachedService
            if (doubleChecked != null && cachedBaseUrl == baseUrl) {
                return doubleChecked
            }

            val retrofit = Retrofit.Builder()
                .baseUrl(baseUrl)
                .addConverterFactory(GsonConverterFactory.create())
                .build()

            val created = retrofit.create(ChronoLensService::class.java)
            cachedBaseUrl = baseUrl
            cachedService = created
            Log.d(TAG, "Retrofit base URL applied: $baseUrl")
            return created
        }
    }

    private fun resolveBaseUrl(context: Context): String {
        val prefs = context.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val savedOrigin = prefs.getString(KEY_BASE_ORIGIN, null)?.trim().orEmpty()
        val base = if (savedOrigin.isNotEmpty()) savedOrigin else DEFAULT_BASE_URL
        return ensureTrailingSlash(base)
    }

    private fun ensureTrailingSlash(url: String): String {
        return if (url.endsWith('/')) url else "$url/"
    }
}
