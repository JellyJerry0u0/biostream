package com.example.biostream.network

import retrofit2.Response
import retrofit2.http.Body
import retrofit2.http.POST

interface ChronoLensService {
    @POST("api/v1/sync-health")
    suspend fun syncHealthData(
        @Body data: HealthDataDto
    ): Response<Unit>

    @POST("api/v1/outdoor-check-response")
    suspend fun submitOutdoorCheckResponse(
        @Body data: OutdoorCheckResponseDto
    ): Response<Unit>
}
