package com.example.biostream.network

data class OutdoorCheckResponseDto(
    val date: String,
    val answer: String,
    val stepsSnapshot: Int,
)
