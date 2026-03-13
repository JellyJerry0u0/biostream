package com.example.biostream.network

data class HealthDataDto(
    val date: String,
    val steps: Long,
    val sleepMinutes: Long,
    val userId: Int,
    val distanceMeters: Double = 0.0,
    val oxygenSaturation: Double = 0.0,
    val averageSpeedMps: Double = 0.0,
    val nutritionCaloriesKcal: Double = 0.0,
    val exerciseMinutes: Long = 0L,
    val fitnessScore: Double = 0.0,
    val weightKg: Double = 0.0,
    val heightCm: Double = 0.0,
    val bodyFatPercentage: Double = 0.0,
    val vo2Max: Double = 0.0,
    val bloodGlucoseMgDl: Double = 0.0,
)
