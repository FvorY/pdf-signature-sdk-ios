# PdfSignatureSDK for iOS

[![CI](https://github.com/FvorY/pdf-signature-sdk-ios/actions/workflows/ci.yml/badge.svg)](https://github.com/FvorY/pdf-signature-sdk-ios/actions/workflows/ci.yml)
![iOS 14+](https://img.shields.io/badge/iOS-14%2B-blue)
![License: MIT](https://img.shields.io/badge/license-MIT-green)

Native iOS (Swift) PDF viewer that lets users place, drag, resize and remove
**signature** and **E-Materai** boxes on a document. Positions are returned in
**PDF points**, exactly like the web SDK
[`pdf-signature-esign-sdk`](https://www.npmjs.com/package/pdf-signature-esign-sdk) v1.1.2,
so the same backend can complete the signing.

> 🚧 **Preview.** The native viewer is usable and the public API is under stabilization; it is not
> yet a 1.0.0 release.

Bahasa Indonesia: [README.id.md](README.id.md)

Documentation: [DOCUMENTATION.en.md](DOCUMENTATION.en.md) · [Dokumentasi Bahasa Indonesia](DOCUMENTATION.id.md)

## Features

- PDF rendering with PDFKit, pagination, zoom, page fitting and page rendering
- Signature and E-Materai placement with drag, resize, delete and per-item locks
- Web-parity methods, events, JSON output, picker options and skeleton overlay
- Password-protected PDFs
- Configurable labels, item locks and secure screen (theme, colors and toolbar options are not applied yet)
- UIKit view plus a SwiftUI wrapper
- No third-party dependencies

## Requirements

- iOS 14.0+
- Xcode 16+ / Swift 5.9+

## Installation

### Swift Package Manager

In Xcode choose **File → Add Package Dependencies…**, paste

```
https://github.com/FvorY/pdf-signature-sdk-ios
```

and choose **Branch: main** (there is no release tag yet). Or in `Package.swift`:

```swift
.package(url: "https://github.com/FvorY/pdf-signature-sdk-ios", branch: "main")
```

### CocoaPods

```ruby
pod 'PdfSignatureSDK', :git => 'https://github.com/FvorY/pdf-signature-sdk-ios.git'
```

## Usage

```swift
import PdfSignatureSDK

let viewer = PdfSignatureView(config: PsdkConfig(file: .file(pdfURL)))
view.addSubview(viewer)

viewer.on(.signaturePlaced) { event in print(event) }

// Later, send the positions to your backend:
let json = try JSONEncoder().encode(viewer.getSignatures())
```

Coordinates use the top-left corner of the page as origin, in PDF points
(1/72 inch), and `x, y` is the top-left corner of the item, the same as the web SDK.

See [DOCUMENTATION.en.md](DOCUMENTATION.en.md) for UIKit integration, all public APIs,
events, password-protected PDFs, configuration, and backend payload examples.

### Remote source security

Remote PDF URLs require HTTPS by default. For a trusted legacy HTTP endpoint only, opt in
explicitly with `PsdkConfig(allowInsecureHttp: true)`. Redirects are revalidated and the SDK caps
PDF input at 100 MiB. Signature placement returns coordinates; cryptographic signing and document
integrity must still be enforced by the backend.

## Project layout

| Path | Contents |
|---|---|
| `Sources/PdfSignatureSDK` | The library |
| `Tests/PdfSignatureSDKTests` | Unit tests, including the web SDK parity fixtures (`Parity/`) |
| `Example/` | Demo app and its UI tests (`project.yml` → generated `PdfSignatureExample.xcodeproj`) |
| `parity/` | Where the parity fixtures come from |
| `scripts/test.sh` | Runs the tests on the first available iPhone simulator |

## Running tests

```bash
scripts/test.sh           # unit tests, including the web SDK parity fixtures
scripts/test.sh example   # Example app UI tests: drag, delete, scrolling
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[MIT](LICENSE)
