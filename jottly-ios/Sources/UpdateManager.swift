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

    public var displayNotification: (String, String, String) -> Void
    public lazy var healthStepsTodayCompletion: (Double?, Error?) -> Void = { [unowned self] steps, error in
        guard let steps = steps, error == nil else {
            //                hcLogger.addToLogs(text: "Error fetching health steps \(error!.localizedDescription)")
            //                displayNotification("Error fetching health steps", "\(error!.localizedDescription)", "")
            return
        }
        // TODO: Shouldn't have to do this
        let intSteps = Int(steps)
        if self.previousSteps != nil && self.previousSteps! > intSteps {
            hcLogger.addToLogs(text: "Got health steps of \(intSteps) but had previous HIGHER value of \(self.previousSteps!)")
            self.displayNotification("Got health steps", "\(intSteps)", "Previous HIGHER value of \(self.previousSteps!)")
        } else {
            hcLogger.addToLogs(text: "Got health steps of \(intSteps) and had previous LOWER value of \(self.previousSteps!)")
            self.displayNotification("Got health steps", "\(intSteps)", "Previous LOWER value of \(self.previousSteps!)")
            self.previousSteps = intSteps
            self.assistantToTheUpdateManager.updateServer(
                type: "steps",
                payload: ["steps": intSteps],
                onSuccess: { data in
                    hcLogger.addToLogs(text: "Success updating server with new steps value (health)")
                },
                onError: { error in
                    hcLogger.addToLogs(text: "Error updating server with new steps value (health): \(error.localizedDescription)")
                }
            )
        }
    }
    public lazy var pedoStepsTodayCompletion: (Int?, Error?) -> Void = { [unowned self] steps, error in
        guard let steps = steps, error == nil else {
            hcLogger.addToLogs(text: "Error fetching pedo steps \(error!.localizedDescription)")
//            displayNotification("Error fetching pedo steps", "\(error!.localizedDescription)", "")
            return
        }
        if self.previousSteps != nil && self.previousSteps! > steps {
            hcLogger.addToLogs(text: "Got pedometer steps of \(steps) but had previous HIGHER value of \(self.previousSteps!)")
            self.displayNotification("Got pedometer steps", "\(steps)", "Previous HIGHER value of \(self.previousSteps!)")
        } else {
            hcLogger.addToLogs(text: "Got pedometer steps of \(steps) and had previous LOWER value of \(self.previousSteps!)")
            self.displayNotification("Got pedometer steps", "\(steps)", "Previous LOWER value of \(self.previousSteps!)")
            self.previousSteps = steps
            self.assistantToTheUpdateManager.updateServer(
                type: "steps",
                payload: ["steps": steps],
                onSuccess: { data in
                    hcLogger.addToLogs(text: "Success updating server with new steps value (pedometer)")
                },
                onError: { error in
                    hcLogger.addToLogs(text: "Error updating server with new steps value (pedometer): \(error.localizedDescription)")
                }
            )
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
            } else {
                displayNotification("Distance travelled", "\(distanceBetweenLocations)m", "\(distanceBetweenLocations)m is < 100m so stop")
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

public enum JotRequestError: Error {
    case invalidHTTPResponse(response: URLResponse)
    case badResponseStatusCode(response: HTTPURLResponse)
    case badResponseStatusCodeWithMessage(response: HTTPURLResponse, errorMessage: String)
}

extension JotRequestError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidHTTPResponse(let response):
            return "Invalid HTTP response received: \(response.debugDescription)"
        case .badResponseStatusCode(let response):
            return "Bad response status code received: \(response.statusCode)"
        case .badResponseStatusCodeWithMessage(let response, let errorMessage):
            return "Bad response status code received: \(response.statusCode) with error message: \(errorMessage)"
        }
    }
}

public class JotRequest: NSObject {
    public var data = Data()
    public let task: URLSessionTask

    // We should only ever communicate a maximum of one error
    public internal(set) var error: Error? = nil

    // If there's a bad response status code then we need to wait for
    // data to be received before communicating the error to the handler
    public internal(set) var badResponse: HTTPURLResponse? = nil
    public internal(set) var badResponseError: Error? = nil

    public let onSuccess: (Data) -> Void
    public let onError: (Error) -> Void

    public init(task: URLSessionTask, onSuccess: @escaping (Data) -> Void, onError: @escaping (Error) -> Void) {
        self.task = task
        self.onSuccess = onSuccess
        self.onError = onError
    }

    deinit {
        self.task.cancel()
    }

    func handle(_ response: URLResponse, completionHandler: (URLSession.ResponseDisposition) -> Void) {
        guard self.task != nil else {
            hcLogger.addToLogs(text: "Task not set in request delegate")
            return
        }

//        hcLogger.addToLogs(text: "Task \(self.task!.taskIdentifier) handling response: \(response.debugDescription)")

        guard let httpResponse = response as? HTTPURLResponse else {
            self.handleCompletion(error: JotRequestError.invalidHTTPResponse(response: response))
            completionHandler(.cancel)
            return
        }

        if !(200..<300).contains(httpResponse.statusCode) {
            self.badResponse = httpResponse
        }

        completionHandler(.allow)
    }

    @objc(handleData:)
    func handle(_ data: Data) {
        guard self.task != nil else {
            hcLogger.addToLogs(text: "Task not set in request delegate")
            return
        }

        if let dataString = String(data: data, encoding: .utf8) {
            hcLogger.addToLogs(text: "Task \(self.task.taskIdentifier) handling dataString: \(dataString)")
        } else {
            hcLogger.addToLogs(text: "Task \(self.task.taskIdentifier) handling data")
        }

        guard self.badResponse == nil else {
            let error = JotRequestError.badResponseStatusCode(response: self.badResponse!)

            guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) else {
                self.badResponseError = error
                return
            }

            guard let errorDict = jsonObject as? [String: String] else {
                self.badResponseError = error
                return
            }

            guard let errorShort = errorDict["error"] else {
                self.badResponseError = error
                return
            }

            let errorDescription = errorDict["error_description"]
            let errorString = errorDescription == nil ? errorShort : "\(errorShort): \(errorDescription!)"

            self.badResponseError = JotRequestError.badResponseStatusCodeWithMessage(
                response: self.badResponse!,
                errorMessage: errorString
            )

            return
        }

        self.data.append(data)
    }

    // Server errors are not reported through the error parameter here, by default.
    // The only errors received through the error parameter are client-side errors,
    // such as being unable to resolve the hostname or connect to the host.
    func handleCompletion(error: Error? = nil) {
        guard self.task != nil else {
            hcLogger.addToLogs(text: "Task not set in request delegate")
            return
        }

//        hcLogger.addToLogs(text: "Task \(self.task!.taskIdentifier) handling completion")

        // TODO: The request is probably DONE DONE so we can tear it all down? Yeah?

        let err = error ?? self.badResponseError

        guard let errorToReport = err else {
            onSuccess(self.data)
            return
        }

        guard self.error == nil else {
            if (errorToReport as NSError).code == NSURLErrorCancelled {
                hcLogger.addToLogs(text: "Request cancelled")
            } else {
                hcLogger.addToLogs(text:
                    "Request has already communicated an error: \(String(describing: self.error!.localizedDescription)). New error: \(String(describing: error))"
                )
            }

            return
        }

        self.error = errorToReport
        self.onError(errorToReport)
    }

}

public class JotURLSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {
    public var requests: [TaskIdentifier: JotRequest] = [:]
    public let lock = NSLock()

    public subscript(task: URLSessionTask) -> JotRequest? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return requests[task.taskIdentifier]
        }

        set {
            lock.lock()
            defer { lock.unlock() }
            requests[task.taskIdentifier] = newValue
        }
    }

    public init(dummy: String = "") {}

    // MARK: URLSessionDelegate

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        self.requests = [:]
    }


    // MARK: URLSessionTaskDelegate

    // TOOD: Should this be communicated somehow? Only used by the background session(s) by default
    public func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        //        self.logger?.log("Task with taskIdentifier \(task.taskIdentifier) is waiting for connectivity", logLevel: .verbose)
        hcLogger.addToLogs(text: "Waiting for connectivity")
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let request = self[task] else {
            guard let error = error else {
                hcLogger.addToLogs(text:
                    "No request found paired with taskIdentifier \(task.taskIdentifier), which encountered an unknown error"
                )
                return
            }

            if (error as NSError).code == NSURLErrorCancelled {
                hcLogger.addToLogs(text:
                    "No request found paried with taskIdentifier \(task.taskIdentifier) as request was cancelled; likely due to an explicit call to end it, or a heartbeat timeout"
                )
            } else {
                hcLogger.addToLogs(text:
                    "No request found paired with taskIdentifier \(task.taskIdentifier), which encountered error: \(error.localizedDescription))"
                )
            }

            return
        }

        request.handleCompletion(error: error)
    }

    //    public func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
    //        hcLogger.addToLogs(text: "urlSession task didCompleteWithError: \(error?.localizedDescription ?? "unknown")")
    //        fatalError("session:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend: has no override in subclass for task \(task.taskIdentifier) in session \(session.sessionDescription ?? "unknown")")
    //    }


    // MARK: URLSessionDataDelegate

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let request = self[dataTask] else {
            hcLogger.addToLogs(text:"No request found paired with taskIdentifier \(dataTask.taskIdentifier), which received some data")
            return
        }

        request.handle(data)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let request = self[dataTask] else {
            hcLogger.addToLogs(text:"No request found paired with taskIdentifier \(dataTask.taskIdentifier), which received response: \(response)")
            completionHandler(.cancel)
            return
        }

        request.handle(response, completionHandler: completionHandler)
    }
}

public typealias TaskIdentifier = Int

public class AssistantToTheUpdateManager {

    public let urlSession: URLSession
    public let jotURLSessionDelegate: JotURLSessionDelegate

    public init() {
        self.jotURLSessionDelegate = JotURLSessionDelegate()

        // TODO: need to look into the appdelegate function aboug background tasks / requests
        self.urlSession = URLSession(
            configuration: URLSessionConfiguration.background(
                withIdentifier: "gg.hc.jottly-ios.jot"
            ),
            delegate: jotURLSessionDelegate,
            delegateQueue: nil
        )
    }

    deinit {
        self.urlSession.invalidateAndCancel()
    }

    func updateServer(type: String, payload: [String: Any], onSuccess: @escaping (Data) -> Void, onError: @escaping (Error) -> Void) {
        var body = payload
        body["type"] = type

        guard let json = try? JSONSerialization.data(withJSONObject: body, options: .prettyPrinted) else {
            // TODO: Fix error
            onError(JotURLSessionError.preExistingTaskIdentifierForRequest)
            return
        }

        var request = URLRequest(url: URL(string: "https://jottly-api.herokuapp.com/jot")!)
        request.httpBody = json
        request.httpMethod = "POST"
        request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let task = urlSession.dataTask(with: request)

        // TODO: We should really be locking the sessionDelegate's list of requests for the check
        // and the assignment together
        guard jotURLSessionDelegate[task] == nil else {
            onError(JotURLSessionError.preExistingTaskIdentifierForRequest)
            return
        }

        let jotReq = JotRequest(task: task, onSuccess: onSuccess, onError: onError)
        jotURLSessionDelegate[task] = jotReq
        task.resume()

//        urlSession.dataTask(with: request, completionHandler: { data, response, error in
//            hcLogger.addToLogs(text: "Update for \(type) got status code: \((response as? HTTPURLResponse)?.statusCode ?? 0))")
//        }).resume()
    }
}

internal enum JotURLSessionError: Error {
    case invalidRawURL(_: String)
    case invalidURL(components: URLComponents)
    case preExistingTaskIdentifierForRequest
}

extension JotURLSessionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidRawURL(let url):
            return "Invalid URL: \(url)"
        case .invalidURL(let components):
            return "Invalid URL from components: \(components.debugDescription)"
        case .preExistingTaskIdentifierForRequest:
            return "Task identifier already in use for another request"
        }
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
