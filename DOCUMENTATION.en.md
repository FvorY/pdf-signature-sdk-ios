# PdfSignatureSDK iOS

This document covers installing and using `PdfSignatureSDK` in an iOS app. The SDK provides a PDF
viewer with an overlay for signatures and E-Materai. The digital signing itself is still done by
the app's backend.

## Features

- Open PDFs from a local file, `Data`, the app bundle, or a remote HTTPS URL.
- Multi-page documents with pagination, zoom, fit-to-screen, and fit-to-width.
- Add signature boxes to a given page.
- Add E-Materai boxes to a given page.
- Move, resize, remove, or lock items.
- Pickers for choosing a signer role and an E-Materai type.
- Coordinates in PDF points, compatible with the web SDK.
- Password-protected PDFs.
- Skeleton/loading overlay while the app uploads or signs.
- Events for document loaded, page changes, items placed/moved/removed, and password requests.
- Configuration for labels, item locks, initial scale, and secure screen.
- Use it directly in UIKit as a `UIView`, or in SwiftUI through `PdfSignatureViewer`.

## Requirements

| | Minimum | Notes |
|---|---|---|
| iOS | 14.0 | |
| Xcode / Swift | 16 / 5.9 | |
| Installation | Swift Package Manager or CocoaPods | Both are checked in CI (`pod lib lint`, Example app). |
| Dependencies | none | Apple `UIKit`, `PDFKit` and `Combine` only. |

## Installation

### Swift Package Manager

In Xcode choose **File → Add Package Dependencies…**, enter the URL below, then choose the
**Branch: main** rule:

```text
https://github.com/FvorY/pdf-signature-sdk-ios
```

Or in `Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/FvorY/pdf-signature-sdk-ios",
        branch: "main"
    )
]
```

Then add the `PdfSignatureSDK` product to your app target.

### CocoaPods

```ruby
pod 'PdfSignatureSDK', :git => 'https://github.com/FvorY/pdf-signature-sdk-ios.git'
```

Run:

```bash
pod install
```

Open the `.xcworkspace` file, not the `.xcodeproj`.

The current version is a preview (`0.0.0`) with no release tag yet, so use the `main` branch.

## UIKit

`PdfSignatureView` is a `UIView` subclass and can be added directly to a `UIViewController`.

```swift
import UIKit
import PdfSignatureSDK

@MainActor
final class PdfViewController: UIViewController {
    private let viewer = PdfSignatureView()

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(viewer)
        viewer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            viewer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            viewer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            viewer.topAnchor.constraint(equalTo: view.topAnchor),
            viewer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        Task {
            do {
                try await viewer.loadDocument(.file(pdfURL))
            } catch {
                print("Could not open the PDF: \(error)")
            }
        }
    }
}
```

The PDF can also be loaded when the view is created:

```swift
let config = PsdkConfig(file: .file(pdfURL))
let viewer = PdfSignatureView(config: config)
```

Available sources:

```swift
.file(URL(fileURLWithPath: path))
.data(pdfData)
.bundle(name: "example.pdf")
.remote(URL(string: "https://example.com/document.pdf")!)
```

## Placing signatures and E-Materai

```swift
let signatureID = try viewer.placeSignature(PlaceOptions(
    x: 80,
    y: 120,
    page: 1,
    label: "Director",
    width: 160,
    height: 48
))

let stampID = try viewer.placeEStamp(PlaceOptions(
    x: 300,
    y: 120,
    page: 1,
    width: 80,
    height: 80,
    locked: true
))
```

Without both `x` and `y`, the item is centered on the page using the default size (160 × 48 for
signatures, 80 × 80 for E-Materai), like the web SDK.

On screen, drag an item to move it, drag the handle on its bottom-right corner to resize it, and
tap the button on its top-right corner to delete it. Touches elsewhere scroll and zoom the PDF.
VoiceOver reads each item and offers a Delete action.

To open the built-in picker:

```swift
viewer.openSignatureModal()
viewer.openEStampModal()
```

Main `PlaceOptions` fields:

| Option | Purpose |
|---|---|
| `x`, `y` | Top-left position in PDF points |
| `page` | Page number, starting at 1 |
| `label` | Signature label (default `"Signature"`). E-Materai is always labelled `"E-Materai"`, like the web SDK |
| `image` | Signature or E-Materai image |
| `width`, `height` | Size in PDF points |
| `disableDrag` / `disableDragging` | Prevent the item from being moved |
| `disableResize` | Prevent the item from being resized |
| `locked` | Lock the item |

## Reading the result

```swift
let items = viewer.getSignatures()
let jsonData = try JSONEncoder().encode(items)
let json = String(data: jsonData, encoding: .utf8)
```

Example item:

```json
{
  "id": "signature-1760600000000-1",
  "type": "signature",
  "x": 80,
  "y": 120,
  "page": 1,
  "label": "Director",
  "width": 160,
  "height": 48,
  "disableDrag": false,
  "disableDragging": false,
  "disableResize": false,
  "locked": false
}
```

Coordinate system:

- unit: PDF point, 1/72 inch;
- origin: top-left corner of the page;
- `x` and `y`: top-left corner of the item;
- page numbers start at 1;
- portrait A4 is usually `595 × 842` points.

`yFromBottom(pageHeight:)` converts `y` for PDF libraries that use a bottom-left origin.

## Events

```swift
viewer.on(.documentLoaded) { event in
    if case let .documentLoaded(totalPages) = event {
        print("Total pages: \(totalPages)")
    }
}

viewer.on(.signaturePlaced) { event in
    if case let .signaturePlaced(item) = event {
        print("Signature placed: \(item.id)")
    }
}

viewer.on(.signatureMoved) { event in
    print("Item position changed: \(event)")
}
```

Available events: `documentLoaded`, `pageChanged`, `signaturePlaced`, `eStampPlaced`,
`signatureMoved`, `signatureRemoved`, `signaturesCleared`, and `passwordRequested`.

`on` and `once` return a `PsdkSubscription`; pass it to `off` to stop listening. With Combine,
use `eventsPublisher` instead.

## Pages, zoom, and lifecycle

```swift
viewer.nextPage()
viewer.prevPage()
viewer.goToPage(2)

Task {
    await viewer.fitToScreen()
    await viewer.fitToWidth()
    await viewer.setScale(1.5)
}

viewer.setPaginationLocked(true)
viewer.removeSignature(signatureID)
viewer.clearSignatures()
```

Supported zoom is 0.25 to 4.0. Without `PsdkConfig(scale:)` the page width fits the view. Call
`destroy()` when the view is no longer used.

## Password-protected PDFs

When a PDF is locked, the SDK sends a `passwordRequested` event:

```swift
viewer.on(.passwordRequested) { event in
    guard case let .passwordRequested(request) = event else { return }

    let alert = UIAlertController(
        title: "PDF password",
        message: request.isIncorrect ? "Wrong password" : nil,
        preferredStyle: .alert
    )
    alert.addTextField { $0.isSecureTextEntry = true }
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
        request.cancel()
    })
    alert.addAction(UIAlertAction(title: "Open", style: .default) { _ in
        request.updatePassword(alert.textFields?.first?.text ?? "")
    })
    present(alert, animated: true)
}
```

## Configuration

```swift
let config = PsdkConfig(
    file: .file(pdfURL),
    labels: .indonesian,
    disableResize: true,
    secureScreen: true
)
```

Change the configuration after the view is created:

```swift
viewer.updateConfig { $0.disabled = true }
```

`secureScreen: true` covers the viewer while the screen is being recorded or mirrored
(`UIScreen.isCaptured`). iOS offers no way to block regular screenshots.

The following options exist in `PsdkConfig` but are **not applied yet** by the preview iOS viewer:
`theme`, `colors`, `typography`, `ui` (toolbar, thumbnails, haptics, built-in password dialog),
`estampKeepAspectRatio`, `logLevel`, and `onUpload`. Picker titles use `labels`; the `label` of
placed items does not (see above).
Handle the `passwordRequested` event yourself, as shown above.

Remote PDF URLs must use HTTPS by default. HTTP can only be enabled explicitly:

```swift
let config = PsdkConfig(allowInsecureHttp: true)
```

Use this only for a trusted legacy endpoint.

## SwiftUI

```swift
import SwiftUI
import PdfSignatureSDK

struct PdfScreen: View {
    @StateObject private var controller = PdfSignatureController()

    var body: some View {
        PdfSignatureViewer(controller: controller)
            .onPsdkEvent(controller) { event in
                print(event)
            }
    }
}
```

`PdfSignatureController` publishes `currentPage`, `totalPages`, `currentScale`, and `signatures`,
and exposes the underlying `PdfSignatureView` as `controller.view`.

## Limitations

The SDK handles display and item positions. It does not:

- create digital signatures or apply certificates;
- verify the signer's identity;
- store documents on the backend;
- finalize the PDF bytes after signing.

Identity checks, coordinate validation, document integrity, and cryptography remain the
backend's responsibility.

## Running tests from source

```bash
scripts/test.sh           # unit tests, including the web SDK parity fixtures
scripts/test.sh example   # Example app UI tests: drag, delete, scrolling
```

License: MIT.
