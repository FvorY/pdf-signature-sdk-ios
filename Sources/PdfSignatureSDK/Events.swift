import Foundation

public enum PageChangeSource: Sendable {
    case scroll
    case api
}

public enum PsdkEventType: Sendable {
    case documentLoaded
    case pageChanged
    case signaturePlaced
    case eStampPlaced
    case signatureMoved
    case signatureRemoved
    case signaturesCleared
    case passwordRequested
}

public enum PsdkEvent {
    case documentLoaded(totalPages: Int)
    case pageChanged(page: Int, total: Int, source: PageChangeSource)
    case signaturePlaced(SignatureItem)
    case eStampPlaced(SignatureItem)
    case signatureMoved(SignatureItem)
    case signatureRemoved(id: String)
    case signaturesCleared
    case passwordRequested(PasswordRequest)

    public var type: PsdkEventType {
        switch self {
        case .documentLoaded: return .documentLoaded
        case .pageChanged: return .pageChanged
        case .signaturePlaced: return .signaturePlaced
        case .eStampPlaced: return .eStampPlaced
        case .signatureMoved: return .signatureMoved
        case .signatureRemoved: return .signatureRemoved
        case .signaturesCleared: return .signaturesCleared
        case .passwordRequested: return .passwordRequested
        }
    }
}

/// Controls the password prompt for a locked PDF.
@MainActor
public final class PasswordRequest {
    public let isIncorrect: Bool
    private let submit: (String) -> Void
    private let cancelHandler: () -> Void

    init(isIncorrect: Bool, submit: @escaping (String) -> Void, cancel: @escaping () -> Void) {
        self.isIncorrect = isIncorrect
        self.submit = submit
        cancelHandler = cancel
    }

    public func updatePassword(_ password: String) { submit(password) }
    public func cancel() { cancelHandler() }
}

public final class PsdkSubscription {
    let id = UUID()
    init() {}
}
