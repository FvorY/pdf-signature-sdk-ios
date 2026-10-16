# PdfSignatureSDK for iOS

[![CI](https://github.com/FvorY/pdf-signature-sdk-ios/actions/workflows/ci.yml/badge.svg)](https://github.com/FvorY/pdf-signature-sdk-ios/actions/workflows/ci.yml)
![iOS 14+](https://img.shields.io/badge/iOS-14%2B-blue)
![License: MIT](https://img.shields.io/badge/license-MIT-green)

Native iOS PDF viewer for placing **signatures** and **E-Materai** on a document. Users can add,
drag, resize, lock, and remove items. The SDK returns positions in PDF points, so the same payload
can be sent to the backend used by the web and Android SDKs.

The Android and iOS SDKs expose the same core concepts: PDF source, item placement, events,
coordinates, JSON/Codable output, and backend signing. Only the UI integration is platform-specific.

> Preview: the viewer and Example app are usable, but the public API may still change before 1.0.0.

Languages and full API documentation:

- [Bahasa Indonesia](README.id.md)
- [English documentation](DOCUMENTATION.en.md)
- [Dokumentasi Bahasa Indonesia](DOCUMENTATION.id.md)

## What it provides

- PDFKit rendering, pagination, thumbnails, zoom, fit-to-screen, and fit-to-width.
- Signature and E-Materai placement with drag, resize, delete, and per-item locks.
- Swift API, event handlers, Combine publisher, and `Codable` output.
- UIKit `PdfSignatureView` (`UIView`) and a SwiftUI wrapper.
- Built-in toolbar for phones and tablets (upload, add, clear, pages, zoom, theme), page indicator,
  thumbnails, status line and empty state, the same as the Android SDK.
- Light, dark and system themes with 18 color tokens, custom font and labels (English and Indonesian).
- Password-protected PDFs (built-in dialog), upload button, skeleton loading, VoiceOver, and secure screen.
- No third-party runtime dependency.

## Requirements

| Component | Requirement |
|---|---|
| iOS | 14.0+ |
| Xcode | 16+ |
| Swift | 5.9+ |
| UI | UIKit or SwiftUI |

## Installation

### Swift Package Manager

In Xcode, choose **File → Add Package Dependencies…**, enter:

```text
https://github.com/FvorY/pdf-signature-sdk-ios
```

Select **Branch: main** because there is not a stable release tag yet. The package can also be
declared in `Package.swift`:

```swift
.package(url: "https://github.com/FvorY/pdf-signature-sdk-ios", branch: "main")
```

### CocoaPods

```ruby
pod 'PdfSignatureSDK', :git => 'https://github.com/FvorY/pdf-signature-sdk-ios.git'
```

## Quick start: UIKit

In the samples, `pdfURL` and `pdfData` stand for your own values; everything else is SDK API.

`PdfSignatureView` is a `UIView`, so it can be added directly to an existing UIKit screen:

```swift
import PdfSignatureSDK
import UIKit

let viewer = PdfSignatureView(config: PsdkConfig(file: .file(pdfURL)))
viewer.translatesAutoresizingMaskIntoConstraints = false
view.addSubview(viewer)

NSLayoutConstraint.activate([
    viewer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
    viewer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    viewer.topAnchor.constraint(equalTo: view.topAnchor),
    viewer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
])
```

To load a document after creating the view:

```swift
Task {
    try await viewer.loadDocument(.file(pdfURL))
}
```

## Quick start: SwiftUI

```swift
import PdfSignatureSDK
import SwiftUI

struct SignScreen: View {
    @StateObject private var controller = PdfSignatureController(
        config: PsdkConfig(file: .file(pdfURL))
    )

    var body: some View {
        PdfSignatureViewer(controller: controller)
            .ignoresSafeArea()
    }
}
```

The controller publishes `currentPage`, `totalPages`, `currentScale`, `signatures`, `isLoaded`,
and `isPasswordProtected`.

## PDF sources

```swift
.file(pdfURL)
.data(pdfData)
.remote(URL(string: "https://example.com/document.pdf")!)
.remote(url, headers: ["Authorization": "Bearer <token>"])
.bundle(name: "example.pdf")
```

Remote PDF URLs require HTTPS by default. HTTP can be enabled only for a trusted legacy endpoint:

```swift
let config = PsdkConfig(allowInsecureHttp: true)
```

Downloads are limited to 100 MiB and redirects are revalidated. The SDK does not perform
cryptographic signing; document signing and integrity checks belong in the backend.

## Place items and export the result

```swift
let id = try viewer.placeSignature(
    PlaceOptions(
        x: 72,
        y: 680,
        page: 1,
        label: "Director",
        width: 140,
        height: 60
    )
)

try viewer.placeEStamp(PlaceOptions(x: 420, y: 700, page: 1))

let items = viewer.getSignatures()
let json = try JSONEncoder().encode(items)
viewer.removeSignature(id)
```

Coordinates use PDF points (1/72 inch), with the page's top-left corner as `(0, 0)` and Y
increasing downward. `page` starts at 1. A4 is commonly 595 × 842 points. `SignatureItem` also
provides `yFromBottom(pageHeight)` for PDF libraries using a bottom-left origin.

## Events and state

```swift
let subscription = viewer.on(.signaturePlaced) { event in
    if case let .signaturePlaced(item) = event {
        print(item) // send this to your backend
    }
}

// Call this when the screen no longer needs the listener.
viewer.off(subscription)
```

Available events include `documentLoaded`, `pageChanged`, `signaturePlaced`, `eStampPlaced`,
`signatureMoved`, `signatureRemoved`, `signaturesCleared`, and `passwordRequested`. UIKit users
can also set `PdfSignatureViewDelegate`; Combine users can collect `eventsPublisher`.

## Configuration and security

`PsdkConfig` controls theme, labels, picker options, initial zoom, item locks, UI layout, colors,
typography, and `secureScreen`. Set `secureScreen: true` to cover the viewer while the screen is
recorded or mirrored; iOS gives apps no way to block regular screenshots.

For password-protected PDFs, use the built-in dialog or handle the event yourself:

```swift
viewer.on(.passwordRequested) { event in
    if case let .passwordRequested(request) = event {
        // Show your own dialog, then answer it:
        request.updatePassword("test123") // the text the user typed
        // request.cancel()               // or the user gave up
    }
}
```

Passwords are not included in the event description or viewer state.

## Project layout and tests

| Path | Contents |
|---|---|
| `Sources/PdfSignatureSDK` | iOS library |
| `Tests/PdfSignatureSDKTests` | Unit tests and web parity fixtures |
| `Example/` | Demo app and UI tests |
| `parity/` | Parity fixture sources |
| `scripts/test.sh` | Test runner |

```bash
scripts/test.sh
scripts/test.sh example
```

## License

[MIT](LICENSE)
