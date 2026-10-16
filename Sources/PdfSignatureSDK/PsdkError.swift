import Foundation

/// Errors thrown by the viewer.
public enum PsdkError: Error, Equatable {
    case sourceUnavailable
    case invalidURL
    case invalidResponse
    case httpStatus(Int)
    case documentTooLarge
    case imageTooLarge
    case invalidDocument
    case documentNotLoaded
    case invalidPage
    /// The password prompt was cancelled (Android: `PsdkException.PasswordCancelled`).
    case passwordCancelled
    /// The viewer was destroyed.
    case destroyed
}
