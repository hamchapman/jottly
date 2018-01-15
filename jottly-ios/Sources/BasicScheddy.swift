//import UIKit
//import Foundation
//
//public class BasicDoer: NSObject  {
//    private var timer: Timer?
//
//    // TODO: Try multiple bg tasks
//    private var bgTask: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
//
//    public override init() {
//        super.init()
//        addNotifications()
//    }
//
//    public func start() {
//        setNewTimer()
//        startBackgroundTask()
//    }
//
//    @objc func timerFinishEvent() {
//        hcLogger.addToLogs(text: "Timer fired. App state: \(UIApplication.shared.applicationState.rawValue)")
//
//        stopBackgroundTask()
//        setNewTimer()
//        startBackgroundTask()
//
//
//        // starting from iOS 7 and above stop background task with delay,
//        // otherwise location service won't start
////        self.perform(#selector(stopAndResetBgTaskIfNeeded), with: nil, afterDelay: 1)
//    }
//
//    @objc private func stopBackgroundTask() {
//        hcLogger.addToLogs(text: "stopBackgroundTask")
//        guard bgTask != UIBackgroundTaskInvalid else { return }
//
//        UIApplication.shared.endBackgroundTask(bgTask)
//        bgTask = UIBackgroundTaskInvalid
//    }
//
//    func startBackgroundTask() {
//        hcLogger.addToLogs(text: "startBackgroundTask")
//
//        bgTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
//            hcLogger.addToLogs(text: "background task expiration handler hit")
//            self.stopBackgroundTask()
//            self.timer?.invalidate()
//
//            // TODO: Maybe start new background task (and check / start time
//        })
//    }
//
//    func setNewTimer() {
//        hcLogger.addToLogs(text: "setNewTimer")
//
//        timer = Timer.scheduledTimer(
//            timeInterval: 169,
//            target: self,
//            selector: #selector(timerFinishEvent),
//            userInfo: nil,
//            repeats: false
//        )
//    }
//
//    func cleanUpTimer() {
//        timer?.invalidate()
//        timer = nil
//    }
//
//    public func stop() {
//        stopBackgroundTask()
//        cleanUpTimer()
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
//        hcLogger.addToLogs(text: "applicationDidEnterBackground")
//        stopBackgroundTask()
//        startBackgroundTask()
//    }
//
//    @objc func applicationDidBecomeActive() {
//        hcLogger.addToLogs(text: "applicationDidBecomeActive")
////        stopBackgroundTask()
//    }
//}

