import Foundation
import HealthKit


//HealthKitSetupAssistant.authorizeHealthKit { (authorized, error) in
//
//    guard authorized else {
//
//        let baseMessage = "HealthKit Authorization Failed"
//
//        if let error = error {
//            print("\(baseMessage). Reason: \(error.localizedDescription)")
//        } else {
//            print(baseMessage)
//        }
//
//        return
//    }
//
//    print("HealthKit Successfully Authorized.")
//}




public enum HealthError: Error {
    case notAvailableOnDevice
    case dataTypeNotAvailable
    case stepCountNotSupported
}

// TODO: Description stuff

public class HealthManager {
    // TODO: let healthStore = HKHealthStore()

    public init() {

    }

    func authorizeHealthKit(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, HealthError.notAvailableOnDevice)
            return
        }

        guard let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass),
            let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            let distanceWalkingRunning = HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning),
            let stepCount = HKObjectType.quantityType(forIdentifier: .stepCount),
            let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate),
            let flightsClimbed = HKObjectType.quantityType(forIdentifier: .flightsClimbed),
            let distanceWheelchair = HKObjectType.quantityType(forIdentifier: .distanceWheelchair),
            let pushCount = HKObjectType.quantityType(forIdentifier: .pushCount)
            else {
                completion(false, HealthError.dataTypeNotAvailable)
                return
        }

        let healthKitTypesToRead: Set<HKObjectType> = [
            bodyMass,
            activeEnergy,
            distanceWalkingRunning,
            stepCount,
            heartRate,
            flightsClimbed,
            distanceWheelchair,
            pushCount
        ]

        HKHealthStore().requestAuthorization(
            toShare: nil,
            read: healthKitTypesToRead
        ) { (success, error) in
            completion(success, error)
        }
    }

    func getMostRecentSample(
        for sampleType: HKSampleType,
        completion: @escaping (HKQuantitySample?, Error?) -> Void
        ) {
        let mostRecentPredicate = HKQuery.predicateForSamples(
            withStart: Date.distantPast, // TODO: Probably can just start with midnight of today
            end: Date(),
            options: .strictEndDate
        )

        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false
        )

        let limit = 1

        let sampleQuery = HKSampleQuery(
            sampleType: sampleType,
            predicate: mostRecentPredicate,
            limit: limit,
            sortDescriptors: [sortDescriptor]
        ) { (query, samples, error) in

            //2. Always dispatch to the main thread when complete.
            DispatchQueue.main.async {
                guard let samples = samples,
                    let mostRecentSample = samples.first as? HKQuantitySample else {
                        completion(nil, error)
                        return
                }

                completion(mostRecentSample, nil)
            }
        }

        HKHealthStore().execute(sampleQuery)
    }

    func getStepsToday(completion: @escaping (Double?, Error?) -> Void) {
        guard let stepsQuantityType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            print("Step count is no longer available in HealthKit")
            completion(nil, HealthError.stepCountNotSupported)
            return
        }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )

        let query = HKStatisticsQuery(
            quantityType: stepsQuantityType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                print("Failed to fetch steps = \(error?.localizedDescription ?? "N/A")")
                completion(nil, error!)
                return
            }

            completion(sum.doubleValue(for: HKUnit.count()), nil)
        }

        HKHealthStore().execute(query)
    }

    func getWeight() {
        guard let weightSampleType = HKSampleType.quantityType(forIdentifier: .bodyMass) else {
            print("Body Mass Sample Type is no longer available in HealthKit")
            return
        }

        getMostRecentSample(for: weightSampleType) { (sample, error) in
            guard let sample = sample else {
                // TODO: Something proper
                return
            }

            let weightInKilograms = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
        }
    }

}

