import Foundation
import CoreLocation

public class UpdateManager: NSObject {
    public lazy var scheduledLocationManager: ScheduledLocationManager = { [unowned self] in
        self.scheduledLocationManager = ScheduledLocationManager(delegate: self)
        return self.scheduledLocationManager
    }()
    public let locationManager = CLLocationManager()
    public let healthManager = HealthManager()
    public let pedometerManager = Pedometer()

    let defaults = UserDefaults.standard

    var _previousLocation: CLLocation? = nil
    var _previousLatitude: Double? = nil {
        didSet { defaults.set(self._previousLatitude, forKey: "jottlyPreviousLatitude") }
    }
    var _previousLongitude: Double? = nil {
        didSet { defaults.set(self._previousLongitude, forKey: "jottlyPreviousLatitude") }
    }

    public var previousLocation: CLLocation? {
        set {
            self._previousLocation = newValue
            self._previousLatitude = newValue?.coordinate.latitude
            self._previousLongitude = newValue?.coordinate.longitude
        }
        get {
            return self._previousLocation != nil ? self._previousLocation
                                                 : checkForStoredLocation()
        }
    }

    public var displayNotification: (String, String, String) -> Void
    public let healthStepsTodayCompletion: (Double?, Error?) -> Void
    public let pedoStepsTodayCompletion: (Int?, Error?) -> Void

    public let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    public init(displayNotification: @escaping (String, String, String) -> Void) {
        self.displayNotification = displayNotification
        self.healthStepsTodayCompletion = { steps, error in
            guard let steps = steps, error == nil else {
                hcLogger.addToLogs(text: "Error fetching health steps \(error!.localizedDescription)")
                displayNotification("Error fetching health steps", "\(error!.localizedDescription)", "")
                return
            }
            hcLogger.addToLogs(text: "Health steps today \(steps)")
            displayNotification("Health steps today", "\(steps)", "")
        }

        self.pedoStepsTodayCompletion = { steps, error in
            guard let steps = steps, error == nil else {
                hcLogger.addToLogs(text: "Error fetching pedo steps \(error!.localizedDescription)")
                displayNotification("Error fetching pedo steps", "\(error!.localizedDescription)", "")
                return
            }
            hcLogger.addToLogs(text: "Pedo steps today \(steps)")
            displayNotification("Pedo steps today", "\(steps)", "")
        }
    }

    public func start() {
        configureLocationServices()
        configureHealthManager() { success, err in
            guard err == nil else {
                print("Error with health kit: \(err!.localizedDescription)")
                return
            }
            print("Health kit authorisation: \(success)")
        }
    }

    func configureHealthManager(completion: @escaping (Bool, Error?) -> Void) {
        healthManager.authorizeHealthKit(completion: completion)
    }

    func configureLocationServices() {
        locationManager.delegate = self
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        // Request authorization, if needed.

        let authorizationStatus = CLLocationManager.authorizationStatus()
        switch authorizationStatus {
        case .notDetermined:
            // Request authorization.
            locationManager.requestAlwaysAuthorization()
            break
        default:
            break
        }

        locationManager.startMonitoringVisits()
        locationManager.startMonitoringSignificantLocationChanges()
    }

    func updateServer(type: String, data: [String: Any]) {
        var request = URLRequest(url: URL(string: "https://jottly-api.herokuapp.com/update")!)
//        var request = URLRequest(url: URL(string: "https://8a8f83a5.ngrok.io/update")!)

        var body = data
        body["type"] = type

        print("Normally would make request with body: \(body)")

        let json = try! JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
        request.httpBody = json

        request.httpMethod = "POST"
        request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request, completionHandler: { data, response, error in
            print("Update for \(type) got status code: \((response as? HTTPURLResponse)?.statusCode ?? 0))")
        }).resume()
    }

    func getStepsToday() {
        healthManager.getStepsToday(completion: self.healthStepsTodayCompletion)
        pedometerManager.dataToday() { pedoData, error in
            self.pedoStepsTodayCompletion(pedoData?.numberOfSteps, error)
        }
    }

    func checkForStoredLocation() -> CLLocation? {
        var prevLat: Double? = nil
        var prevLong: Double? = nil

        prevLat = defaults.double(forKey: "jottlyPreviousLatitude")
        if prevLat == 0 {
            prevLat = defaults.value(forKey: "jottlyPreviousLatitude") != nil ? prevLat : nil
        }

        prevLong = defaults.double(forKey: "jottlyPreviousLongitude")
        if prevLong == 0 {
            prevLong = defaults.value(forKey: "jottlyPreviousLongitude") != nil ? prevLong : nil
        }

        guard let previousLat = prevLat, let previousLong = prevLong else {
            return nil
        }

        let prevLoc = CLLocation(latitude: previousLat, longitude: previousLong)
        self._previousLocation = prevLoc
        return prevLoc
    }
}

// MARK: CLLocationManagerDelegate

extension UpdateManager: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        var text: String?
        var text2: String?
        if visit.departureDate != Date.distantFuture {
            text = "departed"
            text2 = dateFormatter.string(from: visit.departureDate)
            if !scheduledLocationManager.isRunning {
                scheduledLocationManager.startUpdatingLocation()
            }
        } else if visit.arrivalDate != Date.distantPast {
            text = "arrived"
            text2 = dateFormatter.string(from: visit.arrivalDate)
        }
        guard let action = text, let date = text2 else { return }
        let coords = "\(visit.coordinate.longitude), \(visit.coordinate.latitude)"
        hcLogger.addToLogs(text: "locationManager didVisit \(visit.description)")
        displayNotification(action, date, coords)
        getStepsToday()
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let title = "Sig. Location Update"
        let date = dateFormatter.string(from: location.timestamp)
        let coords = "\(location.coordinate.longitude), \(location.coordinate.latitude)"
        if !scheduledLocationManager.isRunning {
            scheduledLocationManager.startUpdatingLocation()
        }
        hcLogger.addToLogs(text: "locationManager didUpdateLocations SIGGY")
        displayNotification(title, date, coords)
        getStepsToday()
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        hcLogger.addToLogs(text: "locationManager didFailWithError \(error.localizedDescription)")
        displayNotification("Error", "Location Manager", error.localizedDescription)
    }
}


extension UpdateManager: ScheduledLocationManagerDelegate {
    public func scheduledLocationManager(_ manager: ScheduledLocationManager, didFailWithError error: Error) {
        hcLogger.addToLogs(text: "scheduledLocationManager didFailWithError \(error.localizedDescription)")
        displayNotification("Error", "Scheduled Location Manager", error.localizedDescription)
    }

    public func scheduledLocationManager(_ manager: ScheduledLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let lastLocation = locations.last else {
            return
        }

        if let previousLocation = previousLocation {
            let distanceBetweenLocations = previousLocation.distance(from: lastLocation)
            hcLogger.addToLogs(text: "Distance most recent location from previous location is: \(distanceBetweenLocations)m")
            displayNotification("Distance travelled", "\(distanceBetweenLocations)m", "\(distanceBetweenLocations)m")

            if distanceBetweenLocations > 100 {
                displayNotification("Distance travelled", "\(distanceBetweenLocations)m", "\(distanceBetweenLocations)m is > 100m so continue")
            } else {
                manager.stopUpdatingLocation()
            }
        } else {
            hcLogger.addToLogs(text: "No previous location stored")
            displayNotification("Scheduled location manager update", "No previous location stored", "")
        }
        self.previousLocation = lastLocation
        getStepsToday()
    }

    public func scheduledLocationManager(_ manager: ScheduledLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        hcLogger.addToLogs(text: "scheduledLocationManager didChangeAuthorization status to \(status.rawValue)")
    }


}

public class AssistantToTheUpdateManager {

    public init() {

    }

    
}



//public enum LocationFetchingMode {
//    case passive // sig change and visit
//    case active // timer
//}

//public class HCLocationManager {
//
//    public var lastLocation: CLLocation = CLLocation()
//    public var lowPowerModeEnabled: Bool
//
//    public init() {
//        lowPowerModeEnabled = ProcessInfo().isLowPowerModeEnabled
//
//        configureNotifications()
//    }
//
//    func configureNotifications() {
//
//        NotificationCenter.default.addObserver(
//            self,
//            selector: #selector(didChangePowerMode(notification:)),
//            name: NSNotification.Name.NSProcessInfoPowerStateDidChange,
//            object: nil
//        )
//
//    }
//
//    @objc func didChangePowerMode(notification: NSNotification) {
//        self.lowPowerModeEnabled = ProcessInfo().isLowPowerModeEnabled
//    }
//
//}
