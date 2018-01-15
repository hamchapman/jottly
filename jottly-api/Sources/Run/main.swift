import App
import Service
import Vapor
import Foundation

var config = Config.default()
var env = Environment.detect()
var services = Services.default()

if let portString = ProcessInfo.processInfo.environment["PORT"],
    let port = UInt16(portString) {
    let serverConfig = EngineServerConfig(port: port)

    services.register { container in
        return serverConfig
    }
}

try App.configure(&config, &env, &services)

let app = try Application(
    config: config,
    environment: env,
    services: services
)

try App.boot(app)

try app.run()
