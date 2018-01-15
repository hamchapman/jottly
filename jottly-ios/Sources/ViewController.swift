import UIKit
import UserNotifications

class ViewController: UIViewController {

    @IBAction func showLogsButton(_ sender: Any) {
        hcLogger.presentLogsInViewController(self)
    }

    public var updateManager: UpdateManager!

    override func viewDidLoad() {
        super.viewDidLoad()

        hcLogger.addLogViewGesture(self)
        hcLogger.addToLogs(text: "LAUNCHED")

        configureNotifications()

        self.updateManager = UpdateManager(displayNotification: displayNotification)
        self.updateManager.start()
    }

}

// MARK: UNUserNotificationCenterDelegate

extension ViewController: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        hcLogger.addToLogs(text: "NOTIFICATION RECEIVED AND WATNS TO BE SHOWN")
        completionHandler([.sound, .alert, .badge])
    }
}

// MARK: Private

extension ViewController {
    func configureNotifications() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in

        }
    }

    func displayNotification(title: String, subtitle: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

}
