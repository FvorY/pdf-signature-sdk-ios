import PdfSignatureSDK
import SwiftUI

@main
struct PdfSignatureExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// Demo of the SDK: a bundled PDF, the signature and E-Materai pickers, locks and the JSON output.
struct ContentView: View {
    @StateObject private var controller = PdfSignatureController(
        config: PsdkConfig(
            file: .bundle(name: "sample.pdf"),
            theme: .system,
            signatureOptions: [
                PickerOption(id: "direktur", label: "Direktur", group: "Internal"),
                PickerOption(id: "klien", label: "Klien", group: "Eksternal")
            ],
            estampOptions: [PickerOption(id: "materai-10000", label: "Materai 10.000")],
            groupByCategory: true,
            labels: .indonesian,
            ui: PsdkUiConfig(topbar: TopBarConfig(brandText: "PSDK Example"))
        )
    )
    @State private var locked = false
    @State private var showJSON = false
    @State private var log: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            PdfSignatureViewer(controller: controller)
                .onPsdkEvent(controller) { event in
                    log = Array(([describe(event)] + log).prefix(4))
                    if case .documentLoaded = event { placeDemoItems() }
                }
            Divider()
            controls
        }
        .sheet(isPresented: $showJSON) { jsonSheet }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Halaman \(controller.currentPage)/\(controller.totalPages) · \(controller.signatures.count) item")
                .font(.footnote)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    Button("+ Tanda tangan") { controller.view.openSignatureModal() }
                    Button("+ E-Materai") { controller.view.openEStampModal() }
                    Button("Hapus semua") { controller.view.clearSignatures() }
                    Button(locked ? "Buka kunci" : "Kunci item") {
                        locked.toggle()
                        controller.view.updateConfig { $0.disableDragging = locked }
                    }
                    Button("JSON") { showJSON = true }
                }
            }
            ForEach(log, id: \.self) { Text($0).font(.caption2).foregroundColor(.secondary) }
            Text("SDK \(PdfSignatureSDK.version) · web \(PdfSignatureSDK.webParityVersion)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    /// `-psdkDemoPage <n>` places items at known positions on page n (checked against the PDF's grid).
    private func placeDemoItems() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let flag = arguments.firstIndex(of: "-psdkDemoPage"), flag + 1 < arguments.count,
              let page = Int(arguments[flag + 1]) else { return }
        _ = try? controller.view.placeSignature(PlaceOptions(x: 100, y: 100, page: page, label: "x100 y100"))
        _ = try? controller.view.placeEStamp(PlaceOptions(x: 200, y: 300, page: page))
        controller.view.goToPage(page)
    }

    private var jsonSheet: some View {
        ScrollView {
            Text(json).font(.system(.footnote, design: .monospaced)).padding()
        }
    }

    private var json: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(controller.signatures) else { return "[]" }
        return String(data: data, encoding: .utf8) ?? "[]"
    }

    private func describe(_ event: PsdkEvent) -> String {
        switch event {
        case .documentLoaded(let total): return "documentLoaded total=\(total)"
        case let .pageChanged(page, total, _): return "pageChanged \(page)/\(total)"
        case .signaturePlaced(let item), .eStampPlaced(let item), .signatureMoved(let item):
            return "\(event.type) \(item.label) p\(item.page) x=\(Int(item.x)) y=\(Int(item.y))"
        case .signatureRemoved(let id): return "signatureRemoved \(id)"
        case .signaturesCleared: return "signaturesCleared"
        case .passwordRequested: return "passwordRequested"
        }
    }
}
