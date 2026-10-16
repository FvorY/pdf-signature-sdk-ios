#if canImport(UIKit) && canImport(PDFKit)

import UIKit

/// Reading PDFs and item images from files, the bundle, Base64 and HTTPS, with size limits.
extension PdfSignatureView {
    func loadData(_ source: PdfSource) async throws -> Data {
        switch source {
        case .data(let value):
            try Self.validateDocumentSize(value.count)
            return value
        case .file(let url):
            return try await Task.detached { try Self.readLocalData(from: url) }.value
        case .bundle(let name, let bundle):
            guard let url = bundle.url(forResource: name, withExtension: nil) else {
                throw PsdkError.sourceUnavailable
            }
            return try await Task.detached { try Self.readLocalData(from: url) }.value
        case .remote(let url, let headers):
            guard isAllowedRemoteURL(url) else { throw PsdkError.invalidURL }
            var request = URLRequest(url: url)
            headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
            let loader = LimitedURLSession(
                allowInsecureHttp: config.allowInsecureHttp,
                maxBytes: Self.maxDocumentBytes,
                tooLargeError: .documentTooLarge
            )
            let (data, response): (Data, URLResponse)
            do {
                (data, response) = try await loader.data(for: request)
            } catch let error as PsdkError {
                throw error
            } catch {
                throw PsdkError.sourceUnavailable
            }
            guard let http = response as? HTTPURLResponse else { throw PsdkError.invalidResponse }
            guard (200..<300).contains(http.statusCode) else { throw PsdkError.httpStatus(http.statusCode) }
            try Self.validateDocumentSize(data.count)
            return data
        }
    }

    func loadItemImage(_ image: PsdkImage) async throws -> UIImage? {
        switch image {
        case .image(let value):
            return value
        case .base64(let value):
            let payload: String
            if let comma = value.firstIndex(of: ","), value[..<comma].lowercased().hasPrefix("data:") {
                payload = String(value[value.index(after: comma)...])
            } else {
                payload = value
            }
            guard payload.count <= Self.maxImageBase64Characters,
                  let data = Data(base64Encoded: payload, options: [.ignoreUnknownCharacters]) else { return nil }
            guard data.count <= Self.maxImageBytes else { throw PsdkError.imageTooLarge }
            return UIImage(data: data)
        case .url(let url):
            guard isAllowedRemoteURL(url) else { throw PsdkError.invalidURL }
            let loader = LimitedURLSession(
                allowInsecureHttp: config.allowInsecureHttp,
                maxBytes: Self.maxImageBytes,
                tooLargeError: .imageTooLarge
            )
            let (data, response) = try await loader.data(for: URLRequest(url: url))
            guard let http = response as? HTTPURLResponse else { throw PsdkError.invalidResponse }
            guard (200..<300).contains(http.statusCode) else { throw PsdkError.httpStatus(http.statusCode) }
            guard data.count <= Self.maxImageBytes else { throw PsdkError.imageTooLarge }
            return UIImage(data: data)
        }
    }

    /// Runs off the main thread so a large file does not block the UI.
    nonisolated static func readLocalData(from url: URL) throws -> Data {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let size = attributes[.size] as? NSNumber {
                try validateDocumentSize(size.intValue)
            }
            let data = try Data(contentsOf: url)
            try validateDocumentSize(data.count)
            return data
        } catch let error as PsdkError {
            throw error
        } catch {
            throw PsdkError.sourceUnavailable
        }
    }

    nonisolated static func validateDocumentSize(_ size: Int) throws {
        if size > maxDocumentBytes { throw PsdkError.documentTooLarge }
    }

    func isAllowedRemoteURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), let host = url.host, !host.isEmpty else { return false }
        return scheme == "https" || (config.allowInsecureHttp && scheme == "http")
    }

    nonisolated static let maxDocumentBytes = 100 * 1024 * 1024
    static let maxImageBytes = 10 * 1024 * 1024
    static let maxImageBase64Characters = 14_000_000
}

#endif
