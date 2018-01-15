import Foundation
import CoreLocation

public func updateLocation(_ lastLoc: CLLocation) {
    var cleanedData: [String: Any] = [
        "altitude": lastLoc.altitude,
        "latitude": lastLoc.coordinate.latitude,
        "longitude": lastLoc.coordinate.longitude,
        "speed": lastLoc.speed
    ]

    let intTimestamp = Int(lastLoc.timestamp.timeIntervalSince1970)
    cleanedData["timestamp"] = String(intTimestamp)

    if let locationFloor = lastLoc.floor {
        cleanedData["floor"] = locationFloor.level
    }
}
