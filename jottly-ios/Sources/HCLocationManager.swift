//import Foundation
//import CoreLocation

//public enum LocationFetchingMode {
//    case passive // sig change and visit
//    case active // timer
//}
//
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

