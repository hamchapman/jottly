import UIKit
import Foundation
import CoreLocation

public protocol ScheduledLocationManagerDelegate {
    func scheduledLocationManager(_ manager: ScheduledLocationManager, didFailWithError error: Error)
    func scheduledLocationManager(_ manager: ScheduledLocationManager, didUpdateLocations locations: [CLLocation])
    func scheduledLocationManager(_ manager: ScheduledLocationManager, didChangeAuthorization status: CLAuthorizationStatus)
}

public class ScheduledLocationManager: NSObject, CLLocationManagerDelegate {
    private let maxBGTime: TimeInterval = 170
    private let minBGTime: TimeInterval = 2
    private let minAcceptableLocationAccuracy: CLLocationAccuracy = 5
    private let waitForLocationsTime: TimeInterval = 3

    private let delegate: ScheduledLocationManagerDelegate
    private let manager = CLLocationManager()

    private var isManagerRunning = false
    private var checkLocationTimer: Timer?
    private var waitTimer: Timer?
    private var timeoutTimer: Timer?
    private var bgTask: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
    private var lastLocations = [CLLocation]()

    public private(set) var acceptableLocationAccuracy: CLLocationAccuracy = 100
    public private(set) var checkLocationInterval: TimeInterval = 10
    public private(set) var timeoutTime: TimeInterval = 0
    public private(set) var isRunning = false

    public init(delegate: ScheduledLocationManagerDelegate) {
        self.delegate = delegate
        super.init()
        configureLocationManager()
    }

    private func configureLocationManager() {
        manager.allowsBackgroundLocationUpdates = true
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = kCLDistanceFilterNone
        manager.pausesLocationUpdatesAutomatically = false
        manager.delegate = self
    }

    public func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    public func startUpdatingLocation(
        interval: TimeInterval = 150,
        acceptableLocationAccuracy: CLLocationAccuracy = 100,
        timeout: TimeInterval = 30
    ) {
        if isRunning { stopUpdatingLocation() }

        self.checkLocationInterval = (minBGTime...maxBGTime).contains(interval) ? interval : maxBGTime
        self.acceptableLocationAccuracy = max(minAcceptableLocationAccuracy, acceptableLocationAccuracy)

        isRunning = true

        self.timeoutTime = timeout

        addNotifications()
        startLocationManager()
    }

    public func stopUpdatingLocation() {
        isRunning = false

        stopWaitTimer()
        stopLocationManager()
        stopBackgroundTask()
        stopCheckLocationTimer()
        removeNotifications()
    }

    private func addNotifications() {
        removeNotifications()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidEnterBackground),
            name: NSNotification.Name.UIApplicationDidEnterBackground,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSNotification.Name.UIApplicationDidBecomeActive,
            object: nil
        )
    }

    private func removeNotifications() {
        NotificationCenter.default.removeObserver(self)
    }

    private func startLocationManager() {
        isManagerRunning = true
        manager.startUpdatingLocation()
    }

    private func stopLocationManager() {
        isManagerRunning = false
        manager.stopUpdatingLocation()
    }

    @objc func applicationDidEnterBackground() {
        stopBackgroundTask()
        startBackgroundTask()
    }

    @objc func applicationDidBecomeActive() {
        stopBackgroundTask()
    }

    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        delegate.scheduledLocationManager(self, didChangeAuthorization: status)
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        delegate.scheduledLocationManager(self, didFailWithError: error)
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isManagerRunning else { return } // TODO: Should be stopping updating location updates here?
        guard locations.count > 0 else { return }

        lastLocations = locations

        if acceptableLocationAccuracyRetrieved() {
            handleAcceptableLocationAccuracyRetrieved()
        } else if waitTimer == nil {
            startWaitTimer()
        }

        if timeoutTimer == nil && timeoutTime > 0 {
            startTimeoutTimer()
        }
    }

    private func startCheckLocationTimer() {
        stopCheckLocationTimer()

        checkLocationTimer = Timer.scheduledTimer(
            timeInterval: checkLocationInterval,
            target: self,
            selector: #selector(checkLocationTimerEvent),
            userInfo: nil,
            repeats: false
        )
    }

    private func stopCheckLocationTimer() {
        if let timer = checkLocationTimer {
            timer.invalidate()
            checkLocationTimer = nil
        }
    }

    @objc func checkLocationTimerEvent() {
        stopCheckLocationTimer()

        startLocationManager()

        // starting from iOS 7 and above stop background task with delay,
        // otherwise location service won't start
        self.perform(#selector(stopAndResetBgTaskIfNeeded), with: nil, afterDelay: 1)
    }

    private func startWaitTimer() {
        stopWaitTimer()

        waitTimer = Timer.scheduledTimer(
            timeInterval: waitForLocationsTime,
            target: self,
            selector: #selector(waitTimerEvent),
            userInfo: nil,
            repeats: false
        )
    }

    private func stopWaitTimer() {
        if let timer = waitTimer {
            timer.invalidate()
            waitTimer = nil
        }
    }

    @objc func waitTimerEvent() {
        stopWaitTimer()

        if acceptableLocationAccuracyRetrieved() {
            handleAcceptableLocationAccuracyRetrieved()
        } else {
            startWaitTimer()
        }
    }

    private func handleAcceptableLocationAccuracyRetrieved() {
        startBackgroundTask()
        startCheckLocationTimer()
        stopLocationManager()

        delegate.scheduledLocationManager(self, didUpdateLocations: lastLocations)
    }

    private func startTimeoutTimer() {
        stopTimeoutTimer()

        timeoutTimer = Timer.scheduledTimer(
            timeInterval: timeoutTime,
            target: self,
            selector: #selector(timeoutTimerEvent),
            userInfo: nil,
            repeats: false
        )
    }

    private func stopTimeoutTimer() {
        if let timer = timeoutTimer {
            timer.invalidate()
            timeoutTimer = nil
        }
    }

    @objc func timeoutTimerEvent() {
        stopWaitTimer()
        stopTimeoutTimer()
        startBackgroundTask()
        startCheckLocationTimer()
        stopLocationManager()
        delegate.scheduledLocationManager(self, didUpdateLocations: lastLocations)
    }


    private func acceptableLocationAccuracyRetrieved() -> Bool {
        guard let location = lastLocations.last else { return false }
        // TODO: Log horizontalAccuracy here
        return location.horizontalAccuracy <= acceptableLocationAccuracy
    }

    @objc func stopAndResetBgTaskIfNeeded() {
        if isManagerRunning {
            stopBackgroundTask()
        } else {
            stopBackgroundTask()
            startBackgroundTask()
        }
    }

    private func startBackgroundTask() {
        let state = UIApplication.shared.applicationState

        if ((state == .background || state == .inactive) && bgTask == UIBackgroundTaskInvalid) {
            bgTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
                self.checkLocationTimerEvent()
            })
        }
    }

    @objc private func stopBackgroundTask() {
        guard bgTask != UIBackgroundTaskInvalid else { return }

        UIApplication.shared.endBackgroundTask(bgTask)
        bgTask = UIBackgroundTaskInvalid
    }
}
