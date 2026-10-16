import Foundation

/// Entry point and metadata for the PdfSignatureSDK module.
///
/// The native viewer is available as a preview API while the SDK is completed toward 1.0.0.
public enum PdfSignatureSDK {
    /// Semantic version of this SDK. Kept in sync with the git tag and the podspec.
    public static let version = "0.0.0"

    /// Version of the web SDK (`pdf-signature-esign-sdk`) whose behavior this SDK mirrors.
    public static let webParityVersion = "1.1.2"

    /// Bundle with the SDK's resources (privacy manifest): `Bundle.module` with Swift Package
    /// Manager, the `PdfSignatureSDK.bundle` resource bundle with CocoaPods.
    static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        let framework = Bundle(for: BundleToken.self)
        return framework.url(forResource: "PdfSignatureSDK", withExtension: "bundle").flatMap(Bundle.init(url:)) ?? framework
        #endif
    }
}

private final class BundleToken {}
