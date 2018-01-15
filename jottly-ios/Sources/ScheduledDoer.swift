//import UIKit
//import Foundation
//
//public class ScheduledDoer: NSObject  {
//    private let maxBGTime: TimeInterval = 170
//    private let minBGTime: TimeInterval = 2
//    private let waitForLocationsTime: TimeInterval = 3
//
//    private var scheduleTimer: Timer?
//
//    // TODO: Try multiple bg tasks
//    private var bgTask: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
//
//    public private(set) var scheduleInterval: TimeInterval
//    public private(set) var isRunning = false
//
//    public init(interval: TimeInterval) {
//        self.scheduleInterval = (minBGTime...maxBGTime).contains(interval) ? interval : maxBGTime
//        super.init()
//    }
//
//    public func startSchedule() {
//        if isRunning { stopSchedule() }
//        isRunning = true
//        addNotifications()
//    }
//
//    public func stopSchedule() {
//        isRunning = false
//
//        stopBackgroundTask()
//        stopScheduleIntervalTimer()
//        removeNotifications()
//    }
//
//    private func addNotifications() {
//        removeNotifications()
//
//        NotificationCenter.default.addObserver(
//            self,
//            selector: #selector(applicationDidEnterBackground),
//            name: NSNotification.Name.UIApplicationDidEnterBackground,
//            object: nil
//        )
//
//        NotificationCenter.default.addObserver(
//            self,
//            selector: #selector(applicationDidBecomeActive),
//            name: NSNotification.Name.UIApplicationDidBecomeActive,
//            object: nil
//        )
//    }
//
//    private func removeNotifications() {
//        NotificationCenter.default.removeObserver(self)
//    }
//
//    @objc func applicationDidEnterBackground() {
//        stopBackgroundTask()
//        startBackgroundTask()
//    }
//
//    @objc func applicationDidBecomeActive() {
//        stopBackgroundTask()
//    }
//
//    private func startScheduleIntervalTimer() {
//        stopScheduleIntervalTimer()
//
//        scheduleTimer = Timer.scheduledTimer(
//            timeInterval: scheduleInterval,
//            target: self,
//            selector: #selector(checkLocationTimerEvent),
//            userInfo: nil,
//            repeats: false
//        )
//    }
//
//    private func stopScheduleIntervalTimer() {
//        if let timer = scheduleTimer {
//            timer.invalidate()
//            scheduleTimer = nil
//        }
//    }
//
//    @objc func checkLocationTimerEvent() {
//        stopScheduleIntervalTimer()
//
//        hcLogger.addToLogs(text: "Timer fired in - \(UIApplication.shared.applicationState)")
//
//        // starting from iOS 7 and above stop background task with delay,
//        // otherwise location service won't start
//        self.perform(#selector(stopAndResetBgTaskIfNeeded), with: nil, afterDelay: 1)
//    }
//
//    private func startWaitTimer() {
//        handleAcceptableLocationAccuracyRetrieved()
//    }
//
//    private func handleAcceptableLocationAccuracyRetrieved() {
//        startBackgroundTask()
//        startScheduleIntervalTimer()
//    }
//
//    @objc func stopAndResetBgTaskIfNeeded() {
//        stopBackgroundTask()
//        startBackgroundTask()
//    }
//
//    private func startBackgroundTask() {
//        let state = UIApplication.shared.applicationState
//
//        if ((state == .background || state == .inactive) && bgTask == UIBackgroundTaskInvalid) {
//            bgTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
//                self.checkLocationTimerEvent()
//            })
//        }
//    }
//
//    @objc private func stopBackgroundTask() {
//        guard bgTask != UIBackgroundTaskInvalid else { return }
//
//        UIApplication.shared.endBackgroundTask(bgTask)
//        bgTask = UIBackgroundTaskInvalid
//    }
//}

