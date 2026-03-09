# iOS HealthKit to Sync API Mapping

This document fixes the iOS metric mapping for the existing backend sync endpoint:
`POST /api/v1/sync-health`.

## Target API Contract

Backend request model is defined in `backend/app/api/health.py` (`HealthSyncRequest`).
The iOS payload must use the same camelCase keys as Android (`HealthDataDto`).

Required keys:

- `date` (`YYYY-MM-DD`)
- `userId` (int)
- `steps` (int)
- `sleepMinutes` (int)

Optional keys (send with `0` when no data):

- `distanceMeters` (double)
- `oxygenSaturation` (double)
- `averageSpeedMps` (double)
- `nutritionCaloriesKcal` (double)
- `exerciseMinutes` (int)
- `fitnessScore` (double)
- `weightKg` (double)
- `bodyFatPercentage` (double)
- `vo2Max` (double)
- `bloodGlucoseMgDl` (double)

## HealthKit Mapping Rules

- `steps`:
  - `HKQuantityTypeIdentifier.stepCount`
  - Sum of yesterday range.
- `sleepMinutes`:
  - `HKCategoryTypeIdentifier.sleepAnalysis`
  - Sum of sleep intervals (asleep category values only).
- `distanceMeters`:
  - `HKQuantityTypeIdentifier.distanceWalkingRunning`
  - Sum in meters.
- `oxygenSaturation`:
  - `HKQuantityTypeIdentifier.oxygenSaturation`
  - Daily average.
  - Convert fraction to percent when value is in `0.0..1.0`.
- `nutritionCaloriesKcal`:
  - `HKQuantityTypeIdentifier.dietaryEnergyConsumed`
  - Sum in kilocalories.
- `exerciseMinutes`:
  - `HKQuantityTypeIdentifier.appleExerciseTime`
  - Sum in minutes.
- `averageSpeedMps`:
  - Derived value: `distanceMeters / (exerciseMinutes * 60)`, else `0`.
- `weightKg`:
  - `HKQuantityTypeIdentifier.bodyMass`
  - Latest sample of yesterday in kilograms.
- `bodyFatPercentage`:
  - `HKQuantityTypeIdentifier.bodyFatPercentage`
  - Latest sample of yesterday.
  - Convert fraction to percent when value is in `0.0..1.0`.
- `vo2Max`:
  - `HKQuantityTypeIdentifier.vo2Max`
  - Latest sample of yesterday in `mL/(kg*min)`.
- `bloodGlucoseMgDl`:
  - `HKQuantityTypeIdentifier.bloodGlucose`
  - Latest sample of yesterday in `mg/dL`.
- `fitnessScore`:
  - Same as Android: `vo2Max` if present, else `(exerciseMinutes / 6.0)` clamped to `0..100`.

## Date/User Rules

- Date range is yesterday in local timezone (`startOfYesterday .. startOfToday`).
- API `date` key is yesterday in `YYYY-MM-DD`.
- `userId` is read from Flutter shared preferences key: `flutter.profile_user_id`.
