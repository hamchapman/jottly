import Routing
import Vapor
import Foundation

/// Register your application's routes here.
///
/// [Learn More →](https://docs.vapor.codes/3.0/getting-started/structure/#routesswift)
final class Routes: RouteCollection {
    /// Use this to create any services you may
    /// need for your routes.
    let app: Application

    /// Create a new Routes collection with
    /// the supplied application.
    init(app: Application) {
        self.app = app
    }

    /// See RouteCollection.boot
    func boot(router: Router) throws {
        router.get("hello") { req in
            return "Hello, world!"
        }

        router.post("jot") { req -> String in
            let bodyData = req.body.data!
            let bodyString = String(data: bodyData, encoding: .utf8)!
            print(bodyString)
            return "Jot received!"
        }
    }
}
