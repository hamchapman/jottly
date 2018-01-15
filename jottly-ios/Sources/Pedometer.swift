import Foundation
import CoreMotion

public struct PedometerData {
    public let numberOfSteps: Int

    public let floorsAscended: Int?
    public let floorsDescended: Int?
    public let distance: Double?

    // TODO: Not sure if these ever actually get populated
    public let currentPace: Double?
    public let averageActicePace: Double?
}

public enum PedometerError: Error {
    case stepCountingUnavailable
    case returnedDataNil
}

// TODO: Description stuff

public class Pedometer {
    let pedoMeter: CMPedometer

    public init() {
        self.pedoMeter = CMPedometer()
    }

    public func dataToday(completionHandler: @escaping (PedometerData?, Error?) -> Void) {
        guard CMPedometer.isStepCountingAvailable() else {
            print("Step counting unavailable")
            completionHandler(nil, PedometerError.stepCountingUnavailable)
            return
        }

        self.pedoMeter.queryPedometerData(
            from: midnightOfToday(),
            to: Date(),
            withHandler: { pedoData, err in
                guard err == nil else {
                    print("Error getting pedometer data", err!.localizedDescription)
                    completionHandler(nil, err)
                    return
                }

                guard let pedoData = pedoData else {
                    print("Pedometer data is nil")
                    completionHandler(nil, PedometerError.returnedDataNil)
                    return
                }

                let formattedPedoData = self.format(pedometerData: pedoData)
                completionHandler(formattedPedoData, nil)
            }
        )
    }

    func format(pedometerData: CMPedometerData) -> PedometerData {
        return PedometerData(
            numberOfSteps: pedometerData.numberOfSteps.intValue,
            floorsAscended: pedometerData.floorsAscended?.intValue,
            floorsDescended: pedometerData.floorsDescended?.intValue,
            distance: pedometerData.distance?.doubleValue,
            currentPace: pedometerData.currentPace?.doubleValue,
            averageActicePace: pedometerData.averageActivePace?.doubleValue
        )
    }

    func midnightOfToday() -> Date {
        let now = Date()
        let midnightToday = Calendar.current.startOfDay(for: now)

        print("Midnight of today: \(midnightToday)")
        return midnightToday
    }
}
