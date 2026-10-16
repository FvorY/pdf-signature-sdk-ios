import Foundation

/// Downloads with an HTTPS-only policy, at most five validated redirects and a size limit.
final class LimitedURLSession: NSObject, URLSessionDataDelegate {
    private let allowInsecureHttp: Bool
    private let maxBytes: Int
    private let tooLargeError: PsdkError
    private lazy var session = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
    private var buffer = Data()
    private var response: URLResponse?
    private var continuation: CheckedContinuation<(Data, URLResponse), Error>?
    private var task: URLSessionDataTask?
    private var redirectCount = 0
    private var finished = false

    init(allowInsecureHttp: Bool, maxBytes: Int, tooLargeError: PsdkError) {
        self.allowInsecureHttp = allowInsecureHttp
        self.maxBytes = maxBytes
        self.tooLargeError = tooLargeError
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let task = session.dataTask(with: request)
            self.task = task
            task.resume()
        }
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard !finished else {
            completionHandler(.cancel)
            return
        }
        if response.expectedContentLength > Int64(maxBytes) {
            finish(.failure(tooLargeError))
            completionHandler(.cancel)
            return
        }
        self.response = response
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard !finished else { return }
        guard buffer.count <= maxBytes - data.count else {
            finish(.failure(tooLargeError))
            dataTask.cancel()
            return
        }
        buffer.append(data)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        guard !finished else {
            completionHandler(nil)
            return
        }
        redirectCount += 1
        guard redirectCount <= 5 else {
            finish(.failure(PsdkError.sourceUnavailable))
            completionHandler(nil)
            return
        }
        guard let url = request.url,
              let scheme = url.scheme?.lowercased(),
              let host = url.host,
              !host.isEmpty,
              scheme == "https" || (allowInsecureHttp && scheme == "http") else {
            finish(.failure(PsdkError.invalidURL))
            completionHandler(nil)
            return
        }
        var safeRequest = request
        // Never carry credentials to a different redirect destination.
        if let originalHost = task.originalRequest?.url?.host, originalHost != host {
            safeRequest.allHTTPHeaderFields?.keys
                .forEach { safeRequest.setValue(nil, forHTTPHeaderField: $0) }
        }
        completionHandler(safeRequest)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !finished else { return }
        if let error {
            finish(.failure(error))
        } else if let response {
            finish(.success((buffer, response)))
        } else {
            finish(.failure(PsdkError.invalidResponse))
        }
    }

    private func finish(_ result: Result<(Data, URLResponse), Error>) {
        guard !finished else { return }
        finished = true
        let continuation = continuation
        self.continuation = nil
        task?.cancel()
        // The session keeps a strong reference to its delegate until it is invalidated.
        session.finishTasksAndInvalidate()
        switch result {
        case .success(let value): continuation?.resume(returning: value)
        case .failure(let error): continuation?.resume(throwing: error)
        }
    }
}
