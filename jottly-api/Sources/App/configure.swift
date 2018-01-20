import Foundation
import Vapor

/// Called before your application initializes.
///
/// [Learn More →](https://docs.vapor.codes/3.0/getting-started/structure/#configureswift)
public func configure(
    _ config: inout Config,
    _ env: inout Environment,
    _ services: inout Services
) throws {
    // configure your application here
    if let portString = ProcessInfo.processInfo.environment["PORT"], let customPort = UInt16(portString) {
        let serverConfig = EngineServerConfig(hostname: "0.0.0.0", port: customPort, backlog: 1000, workerCount: 10, maxConnectionsPerIP: 100)
        services.register(serverConfig)
    }
}
