import Foundation
import UIKit

public typealias HCLogger = GenericHCLogger<BasicHCLog>

public struct BasicHCLog: HCLog {
    public let date: Date
    public let text: String
    public let logLevel: HCLogLevel

    public init(date: Date, text: String, logLevel: HCLogLevel = .info) {
        self.text = text
        self.date = date
        self.logLevel = logLevel
    }

    public init(text: String, logLevel: HCLogLevel = .info) {
        self.init(date: Date(), text: text, logLevel: logLevel)
    }
}

public protocol HCLog: Codable {

    init(text: String, logLevel: HCLogLevel)

    // TODO: short, medium, long, or unix timestamp version
    var date: Date { get }
    var text: String { get }
    var logLevel: HCLogLevel { get }
}

public enum HCLogLevel: Int, Comparable, Codable {
    case verbose = 1, debug, info, warning, error

    public static func < (a: HCLogLevel, b: HCLogLevel) -> Bool {
        return a.rawValue < b.rawValue
    }

    public func stringRepresentation() -> String {
        switch self {
        case .verbose: return "VERBOSE"
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        }
    }

}


public protocol HCLogStore {
    associatedtype LogType

    func fetchLogs(cursor: String?, limit: Int?) -> [LogType]
    func appendLog(_ log: LogType)
}

extension HCLogStore {
    public func fetchLogs(cursor: String? = nil, limit: Int? = nil) -> [LogType] {
        return fetchLogs(cursor: cursor, limit: limit)
    }
}

public class HCUserDefaultsLogStore<LogType: HCLog>: AnyHCLogStore<LogType> {

    // TODO: This should keep its own cache of logs so that it doesn't
    // have to always fetch to append

    public let defaults = UserDefaults.standard
    public let identifier: String

    public init(identifier: String) {
        self.identifier = identifier
        super.init(self)
    }

    override public func appendLog(_ log: LogType) {
        var currentLogs = self.fetchLogs()
        currentLogs.append(log)

        let encodedLogs = currentLogs.flatMap { try? PropertyListEncoder().encode($0) }

        defaults.set(encodedLogs, forKey: self.identifier)
        defaults.synchronize()
    }

    override public func fetchLogs(cursor: String? = nil, limit: Int? = nil) -> [LogType] {
        let dataLogs = self.defaults.value(forKey: self.identifier) as? [Data]
        return dataLogs?.flatMap { try? PropertyListDecoder().decode(LogType.self, from: $0) } ?? [LogType]()
    }
}

public class HCFileLogStore<LogType: HCLog>: AnyHCLogStore<LogType> {

    // TODO: This should keep its own cache of logs so that it doesn't
    // have to always fetch to append

    public let filePath: URL

    public init(filePath: URL) {
        self.filePath = filePath
        super.init(self)
    }

    override public func appendLog(_ log: LogType) {
        writeToFile(path: filePath, log: log)
    }

    override public func fetchLogs(cursor: String? = nil, limit: Int? = nil) -> [LogType] {
        let logString = readFromFile(path: filePath)

        // TODO: See if Codable can be used to encode / decode "special" format

        let logLines = logString.split(separator: "\n")
        return logLines.flatMap { logLine in
            guard let logLineData = logLine.data(using: .utf8) else {
                return nil
            }

            return try? JSONDecoder().decode(LogType.self, from: logLineData)
        }
    }

//    private func parseLog(from logLine: String) -> LogType? {
//        let logSeparatedByDateKey = logLine.components(separatedBy: "date=")
//        let dateLogSeparatedByTextKey = logSeparatedByDateKey[1].components(separatedBy: " text=")
        // TODO: Get the date somehow? Codable etc? Or just DateFormatter()?
        // DateFormatter().date(from: dateLogSeparatedByTextKey.first!)
//        return HCLog(date: Date(), text: dateLogSeparatedByTextKey.last!)
//        return
//    }

    private func writeToFile(path: URL, log: LogType) {
        guard let encodedLog = try? JSONEncoder().encode(log) else {
            print("Failed to encode log before writing to file. Log: \(log)")
            return
        }

        guard let encodedLogString = String(data: encodedLog, encoding: .utf8) else {
            print("Failed to convert encoded log data to a string before writing to file")
            return
        }

        let textToWrite = "\(encodedLogString)\n"

        if let fileHandle = try? FileHandle(forWritingTo: path) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(textToWrite.data(using: .utf8)!)
            print("Appended to file at path \(path)")
        } else {
            do {
                try textToWrite.write(to: path, atomically: true, encoding: .utf8)
                print("Wrote to file at path \(path)")
            } catch let error {
                print("Error writing file at \(path). Error: \(error)")
            }
        }
    }

    private func readFromFile(path: URL) -> String {
        do {
            return try String(contentsOf: path, encoding: .utf8)
        } catch let err {
            print("Error reading logs from path \(path): \(err)")
            return ""
        }
    }

}

public struct HCLoggerOptions {
    public var printToConsole: Bool

    public init(printToConsole: Bool = true) {
        self.printToConsole = printToConsole
    }
}

public class GenericHCLogger<LogType: HCLog> {
    public var options: HCLoggerOptions

    private lazy var gestureRecognizer: UIGestureRecognizer = {
        if let gesture = self.providedGestureRecognizer {
            return gesture
        } else {
            let gestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(gesturePerformed))
            gestureRecognizer.numberOfTouchesRequired = 3
            gestureRecognizer.direction = .up

            return gestureRecognizer
        }
    }()

    public let providedGestureRecognizer: UIGestureRecognizer?

    public var logs: [LogType] = []
    public var gestureRecognizerToViewControllerMap: [UIGestureRecognizer: UIViewController] = [:]
    public lazy var hcLogsViewController = HCLogsViewController<LogType>(logger: self)

    public let store: AnyHCLogStore<LogType>

    public init(store: AnyHCLogStore<LogType>, options: HCLoggerOptions = HCLoggerOptions(), gestureRecognizer: UIGestureRecognizer? = nil) {
        self.store = store
        self.options = options
        self.providedGestureRecognizer = gestureRecognizer
        self.logs = store.fetchLogs()
    }

    public func addLogViewGesture(_ vc: UIViewController) {
        gestureRecognizerToViewControllerMap[self.gestureRecognizer] = vc
        vc.view.addGestureRecognizer(self.gestureRecognizer)
    }

    @objc public func gesturePerformed(_ recognizer: UIGestureRecognizer) {
        if recognizer.state == .recognized {
            if let vc = gestureRecognizerToViewControllerMap[recognizer] {
                presentLogsInViewController(vc)
            } else {
                print("Did not find registered gesture recognizer")
            }
        }
    }

    public func presentLogsInViewController(_ vc: UIViewController) {
        let navController = UINavigationController(rootViewController: hcLogsViewController)
        vc.present(navController, animated: true)
    }

    // TODO: better log
//    public func log(_ message: @autoclosure @escaping () -> String, logLevel: HCLogLevel) {
////        let log = LogType(text: message(), logLevel: HCLogLevel)
//    }

    // TODO: Option to log by passing in LogType directly rather than string message

    public func addToLogs(text: String) {
        // TODO: Fixme - pass in logLevel
        let log = LogType(text: text, logLevel: .info)

        if options.printToConsole {
            print("[HCLogger]: \(log)")
        }

        self.store.appendLog(log)
        // TODO: Use a success / failure callback here?
        self.logs.append(log)
        hcLogsViewController.logsTableView.reloadData()
    }

    // TODO: Probably need something like this
    public func addToLogs(log: LogType) {
//        debugPrint("DEBUG PRINT HC LOG: \(log.debugDescription)")
        self.store.appendLog(log)
        // TODO: Use a success / failure callback here?
        self.logs.append(log)
        hcLogsViewController.logsTableView.reloadData()
    }

    public func fetchLogs() -> [LogType] {
        return self.store.fetchLogs()
    }
}


private class _AnyHCLogStoreBase<LogType>: HCLogStore {
    init() {
        guard type(of: self) != _AnyHCLogStoreBase.self else {
            fatalError("Cannot initialise, must subclass")
        }
    }

    func fetchLogs(cursor: String?, limit: Int?) -> [LogType] {
        fatalError("Must override")
    }

    func appendLog(_ log: LogType) {
        fatalError("Must override")
    }
}

private final class _AnyHCLogStoreBox<ConcreteHCLogStore: HCLogStore>: _AnyHCLogStoreBase<ConcreteHCLogStore.LogType> {
    // Store the concrete type
    var concrete: ConcreteHCLogStore

    // Define init()
    init(_ concrete: ConcreteHCLogStore) {
        self.concrete = concrete
    }

    override func fetchLogs(cursor: String?, limit: Int?) -> [LogType] {
        return concrete.fetchLogs(cursor: cursor, limit: limit)
    }

    override func appendLog(_ log: LogType) {
        concrete.appendLog(log)
    }
}

public class AnyHCLogStore<LogType>: HCLogStore {
    private let box: _AnyHCLogStoreBase<LogType>

    public init<Concrete: HCLogStore>(_ concrete: Concrete) where Concrete.LogType == LogType {
        box = _AnyHCLogStoreBox(concrete)
    }

    public func fetchLogs(cursor: String?, limit: Int?) -> [LogType] {
        return box.fetchLogs(cursor: cursor, limit: limit)
    }

    public func appendLog(_ log: LogType) {
        box.appendLog(log)
    }
}















