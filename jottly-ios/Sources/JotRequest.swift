import Foundation

public class JotRequest: NSObject {
    public var data = Data()
    public let task: URLSessionTask

    // We should only ever communicate a maximum of one error
    public internal(set) var error: Error? = nil

    // If there's a bad response status code then we need to wait for
    // data to be received before communicating the error to the handler
    public internal(set) var badResponse: HTTPURLResponse? = nil
    public internal(set) var badResponseError: Error? = nil

    public let onSuccess: (Data) -> Void
    public let onError: (Error) -> Void

    public init(task: URLSessionTask, onSuccess: @escaping (Data) -> Void, onError: @escaping (Error) -> Void) {
        self.task = task
        self.onSuccess = onSuccess
        self.onError = onError
    }

    deinit {
        self.task.cancel()
    }

    func handle(_ response: URLResponse, completionHandler: (URLSession.ResponseDisposition) -> Void) {
        guard self.task != nil else {
            hcLogger.addToLogs(text: "Task not set in request delegate")
            return
        }

        //        hcLogger.addToLogs(text: "Task \(self.task!.taskIdentifier) handling response: \(response.debugDescription)")

        guard let httpResponse = response as? HTTPURLResponse else {
            self.handleCompletion(error: JotRequestError.invalidHTTPResponse(response: response))
            completionHandler(.cancel)
            return
        }

        if !(200..<300).contains(httpResponse.statusCode) {
            self.badResponse = httpResponse
        }

        completionHandler(.allow)
    }

    @objc(handleData:)
    func handle(_ data: Data) {
        guard self.task != nil else {
            hcLogger.addToLogs(text: "Task not set in request delegate")
            return
        }

        if let dataString = String(data: data, encoding: .utf8) {
            hcLogger.addToLogs(text: "Task \(self.task.taskIdentifier) handling dataString: \(dataString)")
        } else {
            hcLogger.addToLogs(text: "Task \(self.task.taskIdentifier) handling data")
        }

        guard self.badResponse == nil else {
            let error = JotRequestError.badResponseStatusCode(response: self.badResponse!)

            guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) else {
                self.badResponseError = error
                return
            }

            guard let errorDict = jsonObject as? [String: String] else {
                self.badResponseError = error
                return
            }

            guard let errorShort = errorDict["error"] else {
                self.badResponseError = error
                return
            }

            let errorDescription = errorDict["error_description"]
            let errorString = errorDescription == nil ? errorShort : "\(errorShort): \(errorDescription!)"

            self.badResponseError = JotRequestError.badResponseStatusCodeWithMessage(
                response: self.badResponse!,
                errorMessage: errorString
            )

            return
        }

        self.data.append(data)
    }

    // Server errors are not reported through the error parameter here, by default.
    // The only errors received through the error parameter are client-side errors,
    // such as being unable to resolve the hostname or connect to the host.
    func handleCompletion(error: Error? = nil) {
        guard self.task != nil else {
            hcLogger.addToLogs(text: "Task not set in request delegate")
            return
        }

        //        hcLogger.addToLogs(text: "Task \(self.task!.taskIdentifier) handling completion")

        // TODO: The request is probably DONE DONE so we can tear it all down? Yeah?

        let err = error ?? self.badResponseError

        guard let errorToReport = err else {
            onSuccess(self.data)
            return
        }

        guard self.error == nil else {
            if (errorToReport as NSError).code == NSURLErrorCancelled {
                hcLogger.addToLogs(text: "Request cancelled")
            } else {
                hcLogger.addToLogs(text:
                    "Request has already communicated an error: \(String(describing: self.error!.localizedDescription)). New error: \(String(describing: error))"
                )
            }

            return
        }

        self.error = errorToReport
        self.onError(errorToReport)
    }

}

public enum JotRequestError: Error {
    case invalidHTTPResponse(response: URLResponse)
    case badResponseStatusCode(response: HTTPURLResponse)
    case badResponseStatusCodeWithMessage(response: HTTPURLResponse, errorMessage: String)
}

extension JotRequestError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidHTTPResponse(let response):
            return "Invalid HTTP response received: \(response.debugDescription)"
        case .badResponseStatusCode(let response):
            return "Bad response status code received: \(response.statusCode)"
        case .badResponseStatusCodeWithMessage(let response, let errorMessage):
            return "Bad response status code received: \(response.statusCode) with error message: \(errorMessage)"
        }
    }
}
