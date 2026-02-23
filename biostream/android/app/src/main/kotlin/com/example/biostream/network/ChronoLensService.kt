package com.example.biostream.network

import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.POST

interface ChronoLensService {
    @POST("api/v1/sync-health")
    suspend fun syncHealthData(
        @Body data: HealthDataDto
    ): Response<Unit>
}
