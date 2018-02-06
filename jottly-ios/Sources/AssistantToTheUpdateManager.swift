import Foundation

public class AssistantToTheUpdateManager {

    public let urlSession: URLSession
    public let jotURLSessionDelegate: JotURLSessionDelegate

    public init() {
        self.jotURLSessionDelegate = JotURLSessionDelegate()

        // TODO: need to look into the appdelegate function aboug background tasks / requests
        self.urlSession = URLSession(
            configuration: URLSessionConfiguration.background(
                withIdentifier: "gg.hc.jottly-ios.jot"
            ),
            delegate: jotURLSessionDelegate,
            delegateQueue: nil
        )
    }

    deinit {
        self.urlSession.invalidateAndCancel()
    }

    func updateServer(type: String, payload: [String: Any], onSuccess: @escaping (Data) -> Void, onError: @escaping (Error) -> Void) {
        var body = payload
        body["type"] = type

        guard let json = try? JSONSerialization.data(withJSONObject: body, options: .prettyPrinted) else {
            // TODO: Fix error
            onError(JotURLSessionError.preExistingTaskIdentifierForRequest)
            return
        }

        var request = URLRequest(url: URL(string: "https://jottly-api.herokuapp.com/jot")!)
        request.httpBody = json
        request.httpMethod = "POST"
        request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

        let task = urlSession.dataTask(with: request)

        // TODO: We should really be locking the sessionDelegate's list of requests for the check
        // and the assignment together
        guard jotURLSessionDelegate[task] == nil else {
            onError(JotURLSessionError.preExistingTaskIdentifierForRequest)
            return
        }

        let jotReq = JotRequest(task: task, onSuccess: onSuccess, onError: onError)
        jotURLSessionDelegate[task] = jotReq
        task.resume()

        //        urlSession.dataTask(with: request, completionHandler: { data, response, error in
        //            hcLogger.addToLogs(text: "Update for \(type) got status code: \((response as? HTTPURLResponse)?.statusCode ?? 0))")
        //        }).resume()
    }
}

internal enum JotURLSessionError: Error {
    case invalidRawURL(_: String)
    case invalidURL(components: URLComponents)
    case preExistingTaskIdentifierForRequest
}

extension JotURLSessionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidRawURL(let url):
            return "Invalid URL: \(url)"
        case .invalidURL(let components):
            return "Invalid URL from components: \(components.debugDescription)"
        case .preExistingTaskIdentifierForRequest:
            return "Task identifier already in use for another request"
        }
    }
}
