#if canImport(SwiftUI) && canImport(UIKit)

import SwiftUI
import UIKit

/// SwiftUI state holder for one native PDF signature viewer.
@MainActor
public final class PdfSignatureController: ObservableObject {
    @Published public private(set) var currentPage: Int
    @Published public private(set) var totalPages: Int
    @Published public private(set) var currentScale: CGFloat
    @Published public private(set) var signatures: [SignatureItem]

    public let view: PdfSignatureView
    private var subscriptions: [PsdkSubscription] = []

    public init(config: PsdkConfig = .init()) {
        view = PdfSignatureView(config: config)
        currentPage = view.currentPage
        totalPages = view.totalPages
        currentScale = view.currentScale
        signatures = view.getSignatures()
        subscriptions.append(view.on(.documentLoaded) { [weak self] _ in self?.refresh() })
        subscriptions.append(view.on(.pageChanged) { [weak self] _ in self?.refresh() })
        subscriptions.append(view.on(.signaturePlaced) { [weak self] _ in self?.refresh() })
        subscriptions.append(view.on(.eStampPlaced) { [weak self] _ in self?.refresh() })
        subscriptions.append(view.on(.signatureMoved) { [weak self] _ in self?.refresh() })
        subscriptions.append(view.on(.signatureRemoved) { [weak self] _ in self?.refresh() })
        subscriptions.append(view.on(.signaturesCleared) { [weak self] _ in self?.refresh() })
    }

    private func refresh() {
        currentPage = view.currentPage
        totalPages = view.totalPages
        currentScale = view.currentScale
        signatures = view.getSignatures()
    }

}

/// SwiftUI wrapper around `PdfSignatureView`.
public struct PdfSignatureViewer: UIViewRepresentable {
    public let controller: PdfSignatureController

    public init(controller: PdfSignatureController) { self.controller = controller }

    public func makeUIView(context: Context) -> PdfSignatureView { controller.view }

    public func updateUIView(_ uiView: PdfSignatureView, context: Context) {}
}

public extension View {
    /// Observes all SDK events while keeping the viewer controller as the source of truth.
    func onPsdkEvent(
        _ controller: PdfSignatureController,
        perform: @escaping (PsdkEvent) -> Void
    ) -> some View {
        onReceive(controller.view.eventsPublisher, perform: perform)
    }
}

#endif
