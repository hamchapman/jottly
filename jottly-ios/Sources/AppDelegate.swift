import UIKit
import UserNotifications

public struct TestHCLog: HCLog {
    public let date: Date
    public let text: String
    public let logLevel: HCLogLevel
    public let extra: String = "test"

    public init(date: Date, text: String, logLevel: HCLogLevel = .info) {
        self.text = text
        self.date = date
        self.logLevel = logLevel
    }

    public init(text: String, logLevel: HCLogLevel = .info) {
        self.init(date: Date(), text: text, logLevel: logLevel)
    }
}


//let hcLogger = HCLogger(store: HCUserDefaultsLogStore(identifier: "jottly.logs"))

let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
let logFilePath = dir.appendingPathComponent("jottly-ios.txt")
let hcLogger = GenericHCLogger<TestHCLog>(store: HCFileLogStore(filePath: logFilePath))

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        hcLogger.addToLogs(text: "test at start")

        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            // Enable or disable features based on authorization.
            print("Granted? \(granted)")
        }

//        application.registerForRemoteNotifications()
//        let text = "some text"
//
//        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
//            let path = dir.appendingPathComponent(file)
//
//            do {
//                let text2 = try String(contentsOf: path, encoding: String.Encoding.utf8)
//                print(text2)
//            } catch let err {
//                print("Error: \(err)")
//            }
//        }

//        var request = URLRequest(url: URL(string: "https://requestb.in/1cumied1")!)
//        request.httpBody = "testing initial".data(using: .utf8)
//        request.httpMethod = "POST"
//
//        URLSession.shared.dataTask(with: request) { data, res, err in
//            print(data, res, err)
//        }.resume()

        return true
    }

//    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
//        hcLogger.addToLogs(text: "didRegisterForRemoteNotificationsWithDeviceToken")
//        let deviceTokenString = deviceTokenToString(deviceToken: deviceToken)
//        print("Device token: \(deviceTokenString)")
//    }

//    private func deviceTokenToString(deviceToken: Data) -> String {
//        var deviceTokenString: String = ""
//        for i in 0..<deviceToken.count {
//            deviceTokenString += String(format: "%02.2hhx", deviceToken[i] as CVarArg)
//        }
//        return deviceTokenString
//    }

//    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
//        hcLogger.addToLogs(text: "You should be doing a background fetch right now")
//        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
//            hcLogger.addToLogs(text: "Calling completion handler for fetching new data")
//            completionHandler(.newData)
//        }
//    }

//    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
//
//        var request = URLRequest(url: URL(string: "https://requestb.in/1cumied1")!)
//        request.httpBody = "testing jottly again".data(using: .utf8)
//        request.httpMethod = "POST"
//
//        URLSession.shared.dataTask(with: request) { data, res, err in
//            print(data, res, err)
//            hcLogger.addToLogs(text: "Calling completion handler for notification")
//            completionHandler(.newData)
//        }.resume()
//
//        hcLogger.addToLogs(text: "Received notification and need to provide fetchCompletionHandler \(userInfo)")
//
////        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
////            hcLogger.addToLogs(text: "Calling completion handler for notification")
////            completionHandler(.newData)
////        }
//
////        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
////        let path = dir.appendingPathComponent(file)
////
////        do {
////            let fileHandle = try FileHandle(forWritingTo: path)
////            fileHandle.seekToEndOfFile()
////            fileHandle.write(getTodayString().data(using: .utf8)!)
////        } catch let err {
////            print("Error appending to file at \(path) - probably because it doesn't exist. Error: \(err)")
////            do {
////                try getTodayString().write(to: path, atomically: true, encoding: .utf8)
////            } catch let error {
////                print("Error writing file at \(path). Error: \(error)")
////            }
////        }
//    }

//    func getTodayString() -> String {
//        let date = Date()
//        let calender = Calendar.current
//        let components = calender.dateComponents([.year,.month,.day,.hour,.minute,.second], from: date)
//
//        let year = components.year
//        let month = components.month
//        let day = components.day
//        let hour = components.hour
//        let minute = components.minute
//        let second = components.second
//
//        let todayString = String(year!) + "-" + String(month!) + "-" + String(day!) + " " + String(hour!)  + ":" + String(minute!) + ":" +  String(second!)
//
//        return todayString
//    }

//    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
//        print("Failed to register for remote notifications")
//    }


    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

}
