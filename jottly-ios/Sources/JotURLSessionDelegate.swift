import Foundation

public class JotURLSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {
    public var requests: [TaskIdentifier: JotRequest] = [:]
    public let lock = NSLock()

    public subscript(task: URLSessionTask) -> JotRequest? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return requests[task.taskIdentifier]
        }

        set {
            lock.lock()
            defer { lock.unlock() }
            requests[task.taskIdentifier] = newValue
        }
    }

    // MARK: URLSessionDelegate

    public func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        self.requests = [:]
    }


    // MARK: URLSessionTaskDelegate

    // TOOD: Should this be communicated somehow? Only used by the background session(s) by default
    public func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        //        self.logger?.log("Task with taskIdentifier \(task.taskIdentifier) is waiting for connectivity", logLevel: .verbose)
        hcLogger.addToLogs(text: "Waiting for connectivity")
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let request = self[task] else {
            guard let error = error else {
                hcLogger.addToLogs(text:
                    "No request found paired with taskIdentifier \(task.taskIdentifier), which encountered an unknown error"
                )
                return
            }

            if (error as NSError).code == NSURLErrorCancelled {
                hcLogger.addToLogs(text:
                    "No request found paried with taskIdentifier \(task.taskIdentifier) as request was cancelled; likely due to an explicit call to end it, or a heartbeat timeout"
                )
            } else {
                hcLogger.addToLogs(text:
                    "No request found paired with taskIdentifier \(task.taskIdentifier), which encountered error: \(error.localizedDescription))"
                )
            }

            return
        }

        request.handleCompletion(error: error)
    }


    // MARK: URLSessionDataDelegate

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let request = self[dataTask] else {
            hcLogger.addToLogs(text:"No request found paired with taskIdentifier \(dataTask.taskIdentifier), which received some data")
            return
        }

        request.handle(data)
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let request = self[dataTask] else {
            hcLogger.addToLogs(text:"No request found paired with taskIdentifier \(dataTask.taskIdentifier), which received response: \(response)")
            completionHandler(.cancel)
            return
        }

        request.handle(response, completionHandler: completionHandler)
    }
}

public typealias TaskIdentifier = Int
