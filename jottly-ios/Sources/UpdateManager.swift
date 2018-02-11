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
        didSet {
            hcLogger.addToLogs(text: "Setting user defaults for jottlyPreviousLatitude: \(self._previousLatitude)")
            displayNotification("Setting user defaults for jottlyPreviousLatitude", "\(self._previousLatitude)", "")
            defaults.set(self._previousLatitude, forKey: "jottlyPreviousLatitude")
        }
    }
    var _previousLongitude: Double? = nil {
        didSet {
            hcLogger.addToLogs(text: "Setting user defaults for jottlyPreviousLongitude: \(self._previousLongitude)")
            displayNotification("Setting user defaults for jottlyPreviousLongitude", "\(self._previousLongitude)", "")
            defaults.set(self._previousLongitude, forKey: "jottlyPreviousLongitude")
        }
    }

    public var previousLocation: CLLocation? {
        set {
            hcLogger.addToLogs(text: "Setting _previousLocation: \(newValue)")
            displayNotification("Setting _previousLocation:", "\(newValue)", "")
            self._previousLocation = newValue
            self._previousLatitude = newValue?.coordinate.latitude
            self._previousLongitude = newValue?.coordinate.longitude
        }
        get {
            return self._previousLocation != nil ? self._previousLocation!
                                                 : checkForStoredLocation()
        }
    }

    var _previousSteps: Int? = nil {
        didSet { defaults.set(self._previousSteps, forKey: "jottlyPreviousSteps") }
    }
    public var previousSteps: Int? {
        set { self._previousSteps = newValue }
        get {
            return self._previousSteps != nil ? self._previousSteps!
                                              : checkForStoredSteps()
        }
    }

    public var locationUpdatesWithoutSignifcantDistanceTravelled: Int = 0

    public var displayNotification: (String, String, String) -> Void

    public lazy var healthStepsTodayCompletion: (Double?, Error?) -> Void = { [unowned self] steps, error in
        guard let doubleSteps = steps, error == nil else {
            hcLogger.addToLogs(text: "Error fetching health steps \(error!.localizedDescription)")
            //            displayNotification("Error fetching pedo steps", "\(error!.localizedDescription)", "")
            return
        }

        // TODO: Shouldn't have to do this
        let steps = Int(doubleSteps)
        self.updateStepsIfAppropriate(steps, source: "health")
    }

    public lazy var pedoStepsTodayCompletion: (Int?, Error?) -> Void = { [unowned self] steps, error in
        guard let steps = steps, error == nil else {
            hcLogger.addToLogs(text: "Error fetching pedo steps \(error!.localizedDescription)")
            //            displayNotification("Error fetching pedo steps", "\(error!.localizedDescription)", "")
            return
        }

        self.updateStepsIfAppropriate(steps, source: "pedometer")
    }

    func updateStepsIfAppropriate(_ steps: Int, source: String) {
        let midnightToday = midnightOfToday()

        if let prevSteps = self.previousSteps {
            if let mostRecentStepsUpdateMidnightDate = self.defaults.object(forKey: "jottlyPreviousStepsMidnightDate") as? Date {
                if midnightToday < mostRecentStepsUpdateMidnightDate {
                    return
                } else if midnightToday == mostRecentStepsUpdateMidnightDate {
                    self.updateStepsIfNewValueHigher(prevSteps: prevSteps, newSteps: steps, forMidnightDate: midnightToday, source: source)
                } else if midnightToday > mostRecentStepsUpdateMidnightDate {
                    hcLogger.addToLogs(text: "Got \(source) steps of \(steps) and had previous LOWER value of \(prevSteps)")
                    self.displayNotification("Got \(source) steps", "\(steps)", "Previous LOWER value of \(prevSteps)")
                    self.updateStepsValue(steps, forMidnightDate: midnightToday, source: source)
                }
            }

            self.updateStepsIfNewValueHigher(prevSteps: prevSteps, newSteps: steps, forMidnightDate: midnightToday, source: source)
        } else {
            hcLogger.addToLogs(text: "Got \(source) steps of \(steps) and had no previous value")
            self.displayNotification("Got \(source) steps", "\(steps)", "Had no previous value")
            self.updateStepsValue(steps, forMidnightDate: midnightToday, source: source)
        }
    }

    func updateStepsValue(_ steps: Int, forMidnightDate midnight: Date, source: String) {
        self.previousSteps = steps
        self.defaults.set(midnight, forKey: "jottlyPreviousStepsMidnightDate")
        self.assistantToTheUpdateManager.updateServer(
            type: "steps",
            payload: ["steps": steps],
            onSuccess: { data in
                hcLogger.addToLogs(text: "Success updating server with new steps value (\(source))")
            },
            onError: { error in
                hcLogger.addToLogs(text: "Error updating server with new steps value (\(source)): \(error.localizedDescription)")
            }
        )
    }

    func updateStepsIfNewValueHigher(prevSteps: Int, newSteps: Int, forMidnightDate midnight: Date, source: String) {
        if prevSteps > newSteps {
            hcLogger.addToLogs(text: "Got \(source) steps of \(newSteps) but had previous HIGHER value of \(prevSteps)")
            self.displayNotification("Got \(source) steps", "\(newSteps)", "Previous HIGHER value of \(prevSteps)")
        } else {
            hcLogger.addToLogs(text: "Got \(source) steps of \(newSteps) and had previous LOWER value of \(prevSteps)")
            self.displayNotification("Got \(source) steps", "\(newSteps)", "Previous LOWER value of \(prevSteps)")
            self.updateStepsValue(newSteps, forMidnightDate: midnight, source: source)
        }
    }

    public let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    public let assistantToTheUpdateManager: AssistantToTheUpdateManager

    public init(displayNotification: @escaping (String, String, String) -> Void) {
        self.assistantToTheUpdateManager = AssistantToTheUpdateManager()
        self.displayNotification = displayNotification
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

    func getStepsToday() {
        // TODO: Should we do both? If not, which is priority?
        healthManager.getStepsToday(completion: self.healthStepsTodayCompletion)
        pedometerManager.dataToday() { pedoData, error in
            self.pedoStepsTodayCompletion(pedoData?.numberOfSteps, error)
        }
    }

    func checkForStoredSteps() -> Int? {
        let prevSteps: Int? = defaults.integer(forKey: "jottlyPreviousSteps")
        if prevSteps == 0 {
            return defaults.value(forKey: "jottlyPreviousSteps") != nil ? prevSteps : nil
        }
        return prevSteps
    }

    func checkForStoredLocation() -> CLLocation? {
        var prevLat: Double? = defaults.double(forKey: "jottlyPreviousLatitude")
        if prevLat == 0 {
            prevLat = defaults.value(forKey: "jottlyPreviousLatitude") != nil ? prevLat : nil
        }

        var prevLong: Double? = defaults.double(forKey: "jottlyPreviousLongitude")
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

// TODO: Should previousLocation be being updated from here?
// Or do we always want to trigger a scheduled one to get a consistently accurate location?

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
//        displayNotification(action, date, coords)
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
//        displayNotification(title, date, coords)
        getStepsToday()
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        hcLogger.addToLogs(text: "locationManager didFailWithError \(error.localizedDescription)")
//        displayNotification("Error", "Location Manager", error.localizedDescription)
    }
}


extension UpdateManager: ScheduledLocationManagerDelegate {
    public func scheduledLocationManager(_ manager: ScheduledLocationManager, didFailWithError error: Error) {
        hcLogger.addToLogs(text: "scheduledLocationManager didFailWithError \(error.localizedDescription)")
//        displayNotification("Error", "Scheduled Location Manager", error.localizedDescription)
    }

    public func scheduledLocationManager(_ manager: ScheduledLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let lastLocation = locations.last else {
            return
        }

        if let previousLocation = previousLocation {
            let distanceBetweenLocations = previousLocation.distance(from: lastLocation)
            hcLogger.addToLogs(text: "Distance most recent location from previous location is: \(distanceBetweenLocations)m")
//            displayNotification("Distance travelled", "\(distanceBetweenLocations)m", "\(distanceBetweenLocations)m")

            if distanceBetweenLocations > 100 {
                displayNotification("Distance travelled", "\(distanceBetweenLocations)m", "\(distanceBetweenLocations)m is > 100m so continue")
                locationUpdatesWithoutSignifcantDistanceTravelled = 0
            } else if locationUpdatesWithoutSignifcantDistanceTravelled < 4 {
                displayNotification("Distance travelled", "\(distanceBetweenLocations)m", "\(distanceBetweenLocations)m is < 100m but continuing (\(locationUpdatesWithoutSignifcantDistanceTravelled + 1)/4)")
                locationUpdatesWithoutSignifcantDistanceTravelled += 1
            } else {
                displayNotification("Distance travelled", "\(distanceBetweenLocations)m", "\(distanceBetweenLocations)m is < 100m so stop")
                locationUpdatesWithoutSignifcantDistanceTravelled = 0
                manager.stopUpdatingLocation()
            }
        } else {
            hcLogger.addToLogs(text: "No previous location stored")
            displayNotification("Scheduled location manager update", "No previous location stored", "")
        }

        hcLogger.addToLogs(text: "About to set previous location to: \(lastLocation.coordinate.latitude), \(lastLocation.coordinate.longitude)")
        displayNotification("About to set previous location to", "\(lastLocation.coordinate.latitude), \(lastLocation.coordinate.longitude)", "")
        self.previousLocation = lastLocation
        getStepsToday()
    }

    public func scheduledLocationManager(_ manager: ScheduledLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        hcLogger.addToLogs(text: "scheduledLocationManager didChangeAuthorization status to \(status.rawValue)")
    }

}

func midnightOfToday() -> Date {
    let now = Date()
    let midnightToday = Calendar.current.startOfDay(for: now)

    print("Midnight of today: \(midnightToday)")
    return midnightToday
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
