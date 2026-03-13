import Flutter
import Foundation
import HealthKit
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let devChannelName = "com.example.biostream/dev"
  private let syncService = IOSHealthSyncService()
  private var devChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "IOSHealthSyncChannel") else {
      return
    }

    let channel = FlutterMethodChannel(
      name: devChannelName,
      binaryMessenger: registrar.messenger()
    )
    devChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(
          FlutterError(
            code: "internal_error",
            message: "AppDelegate unavailable",
            details: nil
          )
        )
        return
      }

      switch call.method {
      case "enqueueOneTimeHealthSync":
        self.runYesterdayHealthSync(result: result)
      case "runImmediateHealthSync":
        self.runYesterdayHealthSync(result: result)
      case "runImmediateHealthSyncToday":
        self.runTodayHealthSync(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func runYesterdayHealthSync(result: @escaping FlutterResult) {
    Task {
      do {
        try await syncService.syncYesterdayHealthData()
        await MainActor.run {
          result("synced")
        }
      } catch IOSHealthSyncError.healthDataNotAvailable {
        await MainActor.run {
          result(
            FlutterError(
              code: "healthkit_unavailable",
              message: "HealthKit is not available on this device.",
              details: nil
            )
          )
        }
      } catch IOSHealthSyncError.userIdMissing {
        await MainActor.run {
          result(
            FlutterError(
              code: "user_id_missing",
              message: "profile_user_id is missing. Please login first.",
              details: nil
            )
          )
        }
      } catch IOSHealthSyncError.healthAuthorizationDenied {
        await MainActor.run {
          result(
            FlutterError(
              code: "permission_denied",
              message: "HealthKit permission is required.",
              details: nil
            )
          )
        }
      } catch IOSHealthSyncError.invalidApiBaseUrl {
        await MainActor.run {
          result(
            FlutterError(
              code: "invalid_api_base_url",
              message: "Invalid API base origin.",
              details: nil
            )
          )
        }
      } catch IOSHealthSyncError.httpError(let statusCode, let body) {
        await MainActor.run {
          result(
            FlutterError(
              code: "http_error",
              message: "Sync API failed with status \(statusCode)",
              details: body
            )
          )
        }
      } catch {
        NSLog("[IOSHealthSync] unexpected error: %@", String(describing: error))
        await MainActor.run {
          result(
            FlutterError(
              code: "sync_failed",
              message: "Failed to sync iOS health data: \(String(describing: error))",
              details: String(describing: error)
            )
          )
        }
      }
    }
  }

  private func runTodayHealthSync(result: @escaping FlutterResult) {
    Task {
      do {
        try await syncService.syncTodayHealthData()
        await MainActor.run {
          result("synced")
        }
      } catch IOSHealthSyncError.healthDataNotAvailable {
        await MainActor.run {
          result(
            FlutterError(
              code: "healthkit_unavailable",
              message: "HealthKit is not available on this device.",
              details: nil
            )
          )
        }
      } catch IOSHealthSyncError.userIdMissing {
        await MainActor.run {
          result(
            FlutterError(
              code: "user_id_missing",
              message: "profile_user_id is missing. Please login first.",
              details: nil
            )
          )
        }
      } catch IOSHealthSyncError.healthAuthorizationDenied {
        await MainActor.run {
          result(
            FlutterError(
              code: "permission_denied",
              message: "HealthKit permission is required.",
              details: nil
            )
          )
        }
      } catch IOSHealthSyncError.invalidApiBaseUrl {
        await MainActor.run {
          result(
            FlutterError(
              code: "invalid_api_base_url",
              message: "Invalid API base origin.",
              details: nil
            )
          )
        }
      } catch IOSHealthSyncError.httpError(let statusCode, let body) {
        await MainActor.run {
          result(
            FlutterError(
              code: "http_error",
              message: "Sync API failed with status \(statusCode)",
              details: body
            )
          )
        }
      } catch {
        NSLog("[IOSHealthSync] unexpected error: %@", String(describing: error))
        await MainActor.run {
          result(
            FlutterError(
              code: "sync_failed",
              message: "Failed to sync iOS health data: \(String(describing: error))",
              details: String(describing: error)
            )
          )
        }
      }
    }
  }
}

private enum IOSHealthSyncError: Error {
  case healthDataNotAvailable
  case userIdMissing
  case healthAuthorizationDenied
  case invalidApiBaseUrl
  case httpError(statusCode: Int, body: String)
}

private struct IOSHealthPayload {
  let date: String
  let userId: Int
  let steps: Int
  let sleepMinutes: Int
  let distanceMeters: Double
  let oxygenSaturation: Double
  let averageSpeedMps: Double
  let nutritionCaloriesKcal: Double
  let exerciseMinutes: Int
  let fitnessScore: Double
  let weightKg: Double
  let heightCm: Double
  let bodyFatPercentage: Double
  let vo2Max: Double
  let bloodGlucoseMgDl: Double

  var dictionary: [String: Any] {
    [
      "date": date,
      "userId": userId,
      "steps": steps,
      "sleepMinutes": sleepMinutes,
      "distanceMeters": distanceMeters,
      "oxygenSaturation": oxygenSaturation,
      "averageSpeedMps": averageSpeedMps,
      "nutritionCaloriesKcal": nutritionCaloriesKcal,
      "exerciseMinutes": exerciseMinutes,
      "fitnessScore": fitnessScore,
      "weightKg": weightKg,
      "heightCm": heightCm,
      "bodyFatPercentage": bodyFatPercentage,
      "vo2Max": vo2Max,
      "bloodGlucoseMgDl": bloodGlucoseMgDl
    ]
  }
}

private final class IOSHealthSyncService {
  private let healthStore = HKHealthStore()
  private let userDefaults = UserDefaults.standard

  private let flutterUserIdKey = "flutter.profile_user_id"
  private let flutterApiOriginKey = "flutter.api_base_origin"
  private let defaultApiOrigin = "http://127.0.0.1:8080"
  private let healthKitErrorDomain = "com.healthkit"
  private let noDataErrorCode = 11

  func syncYesterdayHealthData() async throws {
    try await syncHealthData(daysAgo: 1)
  }

  func syncTodayHealthData() async throws {
    try await syncHealthData(daysAgo: 0)
  }

  private func syncHealthData(daysAgo: Int) async throws {
    guard HKHealthStore.isHealthDataAvailable() else {
      throw IOSHealthSyncError.healthDataNotAvailable
    }

    let userId = try resolveUserId()
    let apiURL = try resolveSyncEndpointURL()
    try await requestReadAuthorization()

    let (start, end, targetDateString) = dayRange(daysAgo: daysAgo)

    let steps = Int(try await noDataAsZero {
      try await sumQuantity(
        identifier: .stepCount,
        unit: HKUnit.count(),
        startDate: start,
        endDate: end
      )
    })
    let sleepMinutes = Int(try await noDataAsZero {
      try await totalSleepMinutes(startDate: start, endDate: end)
    })
    let distanceMeters = try await noDataAsZero {
      try await sumQuantity(
        identifier: .distanceWalkingRunning,
        unit: HKUnit.meter(),
        startDate: start,
        endDate: end
      )
    }
    let oxygenAverageRaw = try await noDataAsZero {
      try await averageQuantity(
        identifier: .oxygenSaturation,
        unit: HKUnit.percent(),
        startDate: start,
        endDate: end
      )
    }
    let oxygenSaturation = normalizePercentValue(oxygenAverageRaw)
    let nutritionCaloriesKcal = try await noDataAsZero {
      try await sumQuantity(
        identifier: .dietaryEnergyConsumed,
        unit: HKUnit.kilocalorie(),
        startDate: start,
        endDate: end
      )
    }
    let exerciseMinutes = Int(try await noDataAsZero {
      try await sumQuantity(
        identifier: .appleExerciseTime,
        unit: HKUnit.minute(),
        startDate: start,
        endDate: end
      )
    })
    // 체중은 대상 날짜에 기록이 없을 수 있어 "전체 기록 중 최신값"을 사용
    let weightKg = try await noDataAsZero {
      try await latestQuantityAnyTime(
        identifier: .bodyMass,
        unit: HKUnit.gramUnit(with: .kilo)
      )
    }
    // 신장도 대상 날짜와 무관하게 최신값을 사용 (cm)
    let heightCm = try await noDataAsZero {
      try await latestQuantityAnyTime(
        identifier: .height,
        unit: HKUnit.meterUnit(with: .centi)
      )
    }
    let bodyFatPercentageRaw = try await noDataAsZero {
      try await latestQuantity(
        identifier: .bodyFatPercentage,
        unit: HKUnit.percent(),
        startDate: start,
        endDate: end
      )
    }
    let bodyFatPercentage = normalizePercentValue(bodyFatPercentageRaw)
    let vo2Max = try await noDataAsZero {
      try await latestQuantity(
        identifier: .vo2Max,
        unit: HKUnit(from: "mL/(kg*min)"),
        startDate: start,
        endDate: end
      )
    }
    let bloodGlucoseMgDl = try await noDataAsZero {
      try await latestQuantity(
        identifier: .bloodGlucose,
        unit: HKUnit(from: "mg/dL"),
        startDate: start,
        endDate: end
      )
    }

    let averageSpeedMps = exerciseMinutes > 0
      ? distanceMeters / (Double(exerciseMinutes) * 60.0)
      : 0.0
    let fitnessScore = vo2Max > 0.0
      ? vo2Max
      : min(max(Double(exerciseMinutes) / 6.0, 0.0), 100.0)

    let payload = IOSHealthPayload(
      date: targetDateString,
      userId: userId,
      steps: steps,
      sleepMinutes: sleepMinutes,
      distanceMeters: distanceMeters,
      oxygenSaturation: oxygenSaturation,
      averageSpeedMps: averageSpeedMps,
      nutritionCaloriesKcal: nutritionCaloriesKcal,
      exerciseMinutes: exerciseMinutes,
      fitnessScore: fitnessScore,
      weightKg: weightKg,
      heightCm: heightCm,
      bodyFatPercentage: bodyFatPercentage,
      vo2Max: vo2Max,
      bloodGlucoseMgDl: bloodGlucoseMgDl
    )

    try await postSyncPayload(payload: payload, url: apiURL)
  }

  private func resolveUserId() throws -> Int {
    if let number = userDefaults.object(forKey: flutterUserIdKey) as? NSNumber {
      let value = number.intValue
      if value > 0 { return value }
    }
    throw IOSHealthSyncError.userIdMissing
  }

  private func resolveSyncEndpointURL() throws -> URL {
    let origin = (userDefaults.string(forKey: flutterApiOriginKey) ?? defaultApiOrigin).trimmingCharacters(in: .whitespacesAndNewlines)
    guard !origin.isEmpty else {
      throw IOSHealthSyncError.invalidApiBaseUrl
    }
    let normalized = origin.hasSuffix("/") ? String(origin.dropLast()) : origin
    guard let url = URL(string: normalized + "/api/v1/sync-health") else {
      throw IOSHealthSyncError.invalidApiBaseUrl
    }
    return url
  }

  private func requestReadAuthorization() async throws {
    let identifiers: [HKQuantityTypeIdentifier] = [
      .stepCount,
      .distanceWalkingRunning,
      .oxygenSaturation,
      .dietaryEnergyConsumed,
      .appleExerciseTime,
      .bodyMass,
      .height,
      .bodyFatPercentage,
      .vo2Max,
      .bloodGlucose
    ]

    let quantityTypes: [HKObjectType] = identifiers.compactMap { HKObjectType.quantityType(forIdentifier: $0) }
    guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
      throw IOSHealthSyncError.healthDataNotAvailable
    }

    let readTypes = Set(quantityTypes + [sleepType])
    let granted = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
      healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
        if let error {
          continuation.resume(throwing: error)
          return
        }
        continuation.resume(returning: success)
      }
    }

    if !granted {
      throw IOSHealthSyncError.healthAuthorizationDenied
    }
  }

  private func sumQuantity(
    identifier: HKQuantityTypeIdentifier,
    unit: HKUnit,
    startDate: Date,
    endDate: Date
  ) async throws -> Double {
    guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else { return 0.0 }
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

    return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double, Error>) in
      let query = HKStatisticsQuery(
        quantityType: quantityType,
        quantitySamplePredicate: predicate,
        options: .cumulativeSum
      ) { _, result, error in
        if let error {
          if self.isHealthKitNoDataError(error) {
            continuation.resume(returning: 0.0)
            return
          }
          continuation.resume(throwing: error)
          return
        }
        let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0.0
        continuation.resume(returning: value)
      }
      healthStore.execute(query)
    }
  }

  private func averageQuantity(
    identifier: HKQuantityTypeIdentifier,
    unit: HKUnit,
    startDate: Date,
    endDate: Date
  ) async throws -> Double {
    guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else { return 0.0 }
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

    return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double, Error>) in
      let query = HKStatisticsQuery(
        quantityType: quantityType,
        quantitySamplePredicate: predicate,
        options: .discreteAverage
      ) { _, result, error in
        if let error {
          if self.isHealthKitNoDataError(error) {
            continuation.resume(returning: 0.0)
            return
          }
          continuation.resume(throwing: error)
          return
        }
        let value = result?.averageQuantity()?.doubleValue(for: unit) ?? 0.0
        continuation.resume(returning: value)
      }
      healthStore.execute(query)
    }
  }

  private func latestQuantity(
    identifier: HKQuantityTypeIdentifier,
    unit: HKUnit,
    startDate: Date,
    endDate: Date
  ) async throws -> Double {
    guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else { return 0.0 }
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

    return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double, Error>) in
      let query = HKSampleQuery(
        sampleType: quantityType,
        predicate: predicate,
        limit: 1,
        sortDescriptors: [sort]
      ) { _, samples, error in
        if let error {
          if self.isHealthKitNoDataError(error) {
            continuation.resume(returning: 0.0)
            return
          }
          continuation.resume(throwing: error)
          return
        }
        let quantitySample = samples?.first as? HKQuantitySample
        let value = quantitySample?.quantity.doubleValue(for: unit) ?? 0.0
        continuation.resume(returning: value)
      }
      healthStore.execute(query)
    }
  }

  private func latestQuantityAnyTime(
    identifier: HKQuantityTypeIdentifier,
    unit: HKUnit
  ) async throws -> Double {
    guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else { return 0.0 }
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

    return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double, Error>) in
      let query = HKSampleQuery(
        sampleType: quantityType,
        predicate: nil,
        limit: 1,
        sortDescriptors: [sort]
      ) { _, samples, error in
        if let error {
          if self.isHealthKitNoDataError(error) {
            continuation.resume(returning: 0.0)
            return
          }
          continuation.resume(throwing: error)
          return
        }
        let quantitySample = samples?.first as? HKQuantitySample
        let value = quantitySample?.quantity.doubleValue(for: unit) ?? 0.0
        continuation.resume(returning: value)
      }
      healthStore.execute(query)
    }
  }

  private func totalSleepMinutes(startDate: Date, endDate: Date) async throws -> Double {
    guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return 0.0 }
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
    let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)

    return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Double, Error>) in
      let query = HKSampleQuery(
        sampleType: sleepType,
        predicate: predicate,
        limit: HKObjectQueryNoLimit,
        sortDescriptors: [sort]
      ) { _, samples, error in
        if let error {
          if self.isHealthKitNoDataError(error) {
            continuation.resume(returning: 0.0)
            return
          }
          continuation.resume(throwing: error)
          return
        }

        let total = (samples as? [HKCategorySample])?
          .filter { self.isAsleepSample($0) }
          .reduce(0.0) { partial, sample in
            partial + sample.endDate.timeIntervalSince(sample.startDate) / 60.0
          } ?? 0.0

        continuation.resume(returning: total)
      }
      healthStore.execute(query)
    }
  }

  private func isAsleepSample(_ sample: HKCategorySample) -> Bool {
    let value = sample.value
    if value == HKCategoryValueSleepAnalysis.inBed.rawValue { return false }
    if value == HKCategoryValueSleepAnalysis.awake.rawValue { return false }
    return true
  }

  private func normalizePercentValue(_ value: Double) -> Double {
    if value <= 1.5 {
      return value * 100.0
    }
    return value
  }

  private func isHealthKitNoDataError(_ error: Error) -> Bool {
    let nsError = error as NSError
    return nsError.code == noDataErrorCode
      && (nsError.domain == healthKitErrorDomain || nsError.domain.contains("health"))
  }

  private func noDataAsZero(_ block: () async throws -> Double) async throws -> Double {
    do {
      return try await block()
    } catch {
      if isHealthKitNoDataError(error) {
        NSLog("[IOSHealthSync] no data for metric, defaulting to 0: %@", String(describing: error))
        return 0.0
      }
      throw error
    }
  }

  private func dayRange(daysAgo: Int) -> (Date, Date, String) {
    let calendar = Calendar.current
    let now = Date()
    let startOfToday = calendar.startOfDay(for: now)
    let startOfTarget = calendar.date(byAdding: .day, value: -daysAgo, to: startOfToday) ?? startOfToday
    let endOfTarget = calendar.date(byAdding: .day, value: 1, to: startOfTarget) ?? startOfToday
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return (startOfTarget, endOfTarget, formatter.string(from: startOfTarget))
  }

  private func postSyncPayload(payload: IOSHealthPayload, url: URL) async throws {
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: payload.dictionary)

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw IOSHealthSyncError.httpError(statusCode: -1, body: "Invalid response")
    }

    guard (200...299).contains(httpResponse.statusCode) else {
      let body = String(data: data, encoding: .utf8) ?? ""
      throw IOSHealthSyncError.httpError(statusCode: httpResponse.statusCode, body: body)
    }
  }
}
