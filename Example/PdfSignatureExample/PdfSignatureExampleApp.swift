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

struct ContentView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "signature")
                .font(.system(size: 48))
            Text("PdfSignatureSDK \(PdfSignatureSDK.version)")
                .font(.headline)
            Text("Mirrors web SDK \(PdfSignatureSDK.webParityVersion)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}
