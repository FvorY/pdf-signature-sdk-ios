// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "PdfSignatureSDK",
    defaultLocalization: "en",
    platforms: [.iOS(.v14)],
    products: [
        .library(name: "PdfSignatureSDK", targets: ["PdfSignatureSDK"]),
    ],
    targets: [
        .target(
            name: "PdfSignatureSDK",
            resources: [
                .copy("Resources/PrivacyInfo.xcprivacy"),
            ]
        ),
        .testTarget(
            name: "PdfSignatureSDKTests",
            dependencies: ["PdfSignatureSDK"]
        ),
    ]
)
