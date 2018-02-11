import UIKit
import UserNotifications
import MapKit

class MostRecentTrackedLocation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String? = "Most recently tracked location"

    public init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}

class ViewController: UIViewController {

    @IBAction func showLogsButton(_ sender: Any) {
        hcLogger.presentLogsInViewController(self)
    }

    @IBOutlet weak var mostRecentLocationMapView: MKMapView!
    @IBOutlet weak var stepsTodayLabel: UILabel!
    @IBOutlet weak var mostRecentLatitudeLabel: UILabel!
    @IBOutlet weak var mostRecentLongitudeLabel: UILabel!

    public var updateManager: UpdateManager!

    public var annotations: [MKAnnotation] = []

    public lazy var numberCommaFormatter: NumberFormatter = {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = NumberFormatter.Style.decimal
        return numberFormatter
    }()

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateValues),
            name: NSNotification.Name.UIApplicationWillEnterForeground,
            object: nil
        )

        hcLogger.addLogViewGesture(self)
        hcLogger.addToLogs(text: "LAUNCHED")

        configureNotifications()

        self.updateManager = UpdateManager(displayNotification: displayNotification)
        self.updateManager.start()

        mostRecentLocationMapView.showsUserLocation = true

//        mostRecentLocationMapView.userTrackingMode = .follow

        updateValues()
    }

    @objc func updateValues() {
        if let previousLocation = updateManager.previousLocation {
            centerMapOnLocation(location: previousLocation)
            let mostRecentLocationAnnotation = MostRecentTrackedLocation(coordinate: previousLocation.coordinate)
            annotations.append(mostRecentLocationAnnotation)
            mostRecentLocationMapView.addAnnotation(mostRecentLocationAnnotation)
            mostRecentLatitudeLabel.text = "\(previousLocation.coordinate.latitude)"
            mostRecentLongitudeLabel.text = "\(previousLocation.coordinate.longitude)"
        } else {
            // TODO: Show what? Something based on locale of device?
        }

        if let steps = updateManager.previousSteps {
            stepsTodayLabel.text = numberCommaFormatter.string(from: NSNumber(value: steps))
        } else {
            // TOOD: Show how many steps
        }
    }

    func centerMapOnLocation(location: CLLocation) {
        let regionRadius: CLLocationDistance = 500

        let coordinateRegion = MKCoordinateRegionMakeWithDistance(
            location.coordinate,
            regionRadius,
            regionRadius
        )
        mostRecentLocationMapView.setRegion(coordinateRegion, animated: true)
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
