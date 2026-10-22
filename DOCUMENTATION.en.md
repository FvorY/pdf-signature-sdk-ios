# PdfSignatureSDK for iOS — Guide

The SDK shows a PDF and lets users place **signatures** and **E-Materai** on it. It returns the
positions in PDF points, in the same JSON format as the web SDK
[`pdf-signature-esign-sdk`](https://www.npmjs.com/package/pdf-signature-esign-sdk) 1.1.2, so one
backend can complete the signing for web, Android and iOS.

The Android SDK's [guide](https://github.com/FvorY/pdf-signature-sdk-android/blob/main/DOCUMENTATION.en.md)
has the same sections. Bahasa Indonesia: [DOCUMENTATION.id.md](DOCUMENTATION.id.md).

> **About the code samples.** Everything you see is SDK API except values that stand for your own
> data: `pdfURL`, `pdfData`, and image names such as `"director-signature"`.
> The code is the same in the English and Indonesian guides; only comments and texts in quotes differ.

1. [Requirements and installation](#1-requirements-and-installation)
2. [Showing the viewer](#2-showing-the-viewer)
3. [PDF sources](#3-pdf-sources)
4. [Placing items](#4-placing-items)
5. [Editing on screen](#5-editing-on-screen)
6. [Reading the result](#6-reading-the-result)
7. [Events and state](#7-events-and-state)
8. [Pages and zoom](#8-pages-and-zoom)
9. [Password-protected PDFs](#9-password-protected-pdfs)
10. [Built-in UI](#10-built-in-ui)
11. [Theme, colors, font and labels](#11-theme-colors-font-and-labels)
12. [Upload button](#12-upload-button)
13. [Loading overlay](#13-loading-overlay)
14. [Page images](#14-page-images)
15. [Screen protection](#15-screen-protection)
16. [Errors](#16-errors)
17. [Lifecycle and restoring state](#17-lifecycle-and-restoring-state)
18. [All options](#18-all-options)
19. [Platform differences](#19-platform-differences)
20. [Building from source](#20-building-from-source)

## 1. Requirements and installation

| | Minimum | Notes |
|---|---|---|
| iOS | 14.0 | |
| Xcode / Swift | 16 / 5.9 | |
| Installation | Swift Package Manager or CocoaPods | both are checked in CI (`pod lib lint`, Example app) |
| Dependencies | none | Apple `UIKit`, `PDFKit` and `Combine` only |

**Swift Package Manager.** In Xcode choose **File → Add Package Dependencies…**, enter
`https://github.com/FvorY/pdf-signature-sdk-ios` and choose **Branch: main** (there is no release
tag yet). In `Package.swift`:

```swift
.package(url: "https://github.com/FvorY/pdf-signature-sdk-ios", branch: "main")
```

**CocoaPods.**

```ruby
pod 'PdfSignatureSDK', :git => 'https://github.com/FvorY/pdf-signature-sdk-ios.git'
```

Then run `pod install` and open the `.xcworkspace`.

## 2. Showing the viewer

### SwiftUI

```swift
import PdfSignatureSDK
import SwiftUI

struct SignScreen: View {
    @StateObject private var controller = PdfSignatureController(
        config: PsdkConfig(file: .file(pdfURL))
    )

    var body: some View {
        PdfSignatureViewer(controller: controller)
            .onPsdkEvent(controller) { event in print(event) }
    }
}
```

`PdfSignatureController` publishes `currentPage`, `totalPages`, `currentScale`, `signatures`,
`isLoaded` and `isPasswordProtected`, and gives the viewer as `controller.view` for every method
below.

### UIKit

```swift
import PdfSignatureSDK
import UIKit

final class SignViewController: UIViewController {
    private let viewer = PdfSignatureView(config: PsdkConfig(file: .file(pdfURL)))

    override func viewDidLoad() {
        super.viewDidLoad()
        viewer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(viewer)
        NSLayoutConstraint.activate([
            viewer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            viewer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            viewer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            viewer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
}
```

To open a document later, create the view without `file` and call
`try await viewer.loadDocument(.file(url))`. The view presents its pickers and dialogs from the
nearest view controller, so it must be inside one.

## 3. PDF sources

```swift
.file(url)                                   // local file, read off the main thread
.data(pdfData)
.bundle(name: "example.pdf")                 // app bundle; `bundle:` picks another Bundle
.remote(url, headers: ["Authorization": "Bearer …"])
```

Remote PDFs and images must use HTTPS. `PsdkConfig(allowInsecureHttp: true)` allows HTTP for a
trusted legacy server only. Downloads follow at most five validated redirects, drop headers when the
host changes, and are limited to 100 MiB (PDF) and 10 MiB (image).

## 4. Placing items

```swift
let signatureID = try viewer.placeSignature(PlaceOptions(
    x: 72, y: 680, page: 1, label: "Director",
    image: .url(URL(string: "https://example.com/signature.png")!), width: 140
))
let stampID = try viewer.placeEStamp(PlaceOptions(x: 420, y: 700, page: 1))
```

| `PlaceOptions` | Meaning | Default |
|---|---|---|
| `page` | Page, starting at 1 | current page |
| `x`, `y` | Top-left corner in PDF points | centered, unless both are given |
| `width`, `height` | Size in PDF points | 160 × 48 (signature), 80 × 80 (E-Materai) |
| `label` | Signature text | `"Signature"`; E-Materai is always `"E-Materai"` |
| `image` | `.url(URL)`, `.base64(String)`, `.image(UIImage)`, or `PsdkImage(string:)` | none |
| `disableDrag`, `disableResize`, `disableDragging`, `locked` | Locks for this item (§5) | `false` |

Without `height`, an item with an image takes the image's aspect ratio once the image has loaded
(a `signatureMoved` event reports the new size), like the web SDK.

**Coordinates**: PDF points (1/72 inch), origin at the page's top-left corner as displayed (after
/Rotate), Y down. A4 is about 595 × 842. `getPageSize(page)` returns each page's size, rounded like
the web SDK (A4 is 594.67 × 841.33).

The add buttons and pickers of the built-in UI are described in §10.

### Starting position from the add buttons

By default the add buttons and pickers (and `openSignatureModal()` / `openEStampModal()`) put a new
item in the center of the page, and the user drags it. Set `defaultPosition` to place it at a fixed
position instead, with no dragging needed:

```swift
PsdkConfig(defaultPosition: PlacementPosition(x: 10, y: 20)) // top-left corner, PDF points
// or later: viewer.updateConfig { $0.defaultPosition = PlacementPosition(x: 10, y: 20) }
```

- `x`, `y` use the same coordinates as `PlaceOptions` (top-left origin, Y down, PDF points).
- The item is kept inside the page: a position beyond the page edge is pulled back so the whole item fits.
- It applies to the current page, to signatures and E-Materai, and to items chosen from a picker.
- `null` (default) keeps the centered placement.
- `placeSignature` / `placeEStamp` are not affected: their own `x`, `y` always win.

## 5. Editing on screen

- Drag an item to move it; drag the handle on its bottom-right corner to resize it (at least
  20 pt); tap the button on its top-right corner to delete it. Items stay inside their page.
  Touches outside items scroll and zoom the PDF.
- Locks follow the web SDK: `disableDrag` stops moving, `disableResize` stops resizing,
  `disableDragging` and `locked` stop both. The delete button works even on locked items; only
  `disabled` turns it off. The same locks exist for all items in `PsdkConfig`.
- `estampKeepAspectRatio: true` keeps an E-Materai's width/height ratio while resizing.
- `ui.haptics` gives a short vibration when an item starts moving or is deleted.
- VoiceOver reads each item ("Signature, page 1") and offers move, bigger/smaller and delete actions.

## 6. Reading the result

```swift
let items: [SignatureItem] = viewer.getSignatures()
let onPage2 = viewer.getSignaturesByPage(2)
let json = try JSONEncoder().encode(items) // same fields as the web SDK
```

```json
{"id":"signature-1760600000000-k3x9a","type":"signature","x":72,"y":680,"page":1,"label":"Director",
 "width":140,"height":48,"disableDrag":false,"disableDragging":false,"disableResize":false,"locked":false}
```

`SignatureItem` is `Codable`. `yFromBottom(pageHeight:)` converts `y` for PDF libraries that measure
from the bottom-left corner. `removeSignature(id)` and `clearSignatures()` remove items.

## 7. Events and state

```swift
let subscription = viewer.on(.signaturePlaced) { event in
    if case let .signaturePlaced(item) = event {
        print(item) // send this to your backend
    }
}
viewer.once(.documentLoaded) { event in print(event) }
viewer.off(subscription)
```

| Event | Data | When |
|---|---|---|
| `.documentLoaded` | `totalPages` | a document opened |
| `.pageChanged` | `page`, `total`, `source` (`.scroll` or `.api`) | the current page changed |
| `.signaturePlaced` / `.eStampPlaced` | `SignatureItem` | an item was placed |
| `.signatureMoved` | `SignatureItem` | an item was moved or resized (also after an image sets its height) |
| `.signatureRemoved` | `id` | an item was removed |
| `.signaturesCleared` | – | all items were removed, also when a new document opens |
| `.passwordRequested` | `PasswordRequest` (`isIncorrect`, `updatePassword(_:)`, `cancel()`) | a password is needed (§9) |

Handlers run on the main thread. Combine users can subscribe to `viewer.eventsPublisher`; UIKit
code can set `viewer.delegate`. The view's state is in `currentPage`, `totalPages`, `currentScale`,
`isLoaded`, `isLoading`, `isPaginationLocked` and `isPasswordProtected`; SwiftUI gets it from
`PdfSignatureController`.

## 8. Pages and zoom

```swift
viewer.nextPage(); viewer.prevPage(); viewer.goToPage(3) // false when not possible
viewer.setPaginationLocked(true) // blocks buttons, page input, thumbnails and goToPage
await viewer.setScale(1.5)       // 0.25–4.0
await viewer.fitToScreen(); await viewer.fitToWidth()
```

Without `PsdkConfig(scale:)` the page width fits the view. Users can pinch and double-tap to zoom
(`ui.viewer.zoom = false` turns that off). `lockScrollWhenPaginationLocked: true` also blocks
scrolling while pagination is locked (off by default, like the web SDK).

## 9. Password-protected PDFs

`loadDocument` waits until a password opens the document, and throws `PsdkError.passwordCancelled`
when the prompt is cancelled. The built-in dialog (`ui.passwordDialog`, on by default) asks for the
password; the `.passwordRequested` event is sent either way, so you can show your own dialog instead:

```swift
var ui = PsdkUiConfig()
ui.passwordDialog = false
let viewer = PdfSignatureView(config: PsdkConfig(ui: ui))
viewer.on(.passwordRequested) { event in
    guard case let .passwordRequested(request) = event else { return }
    // Show your own dialog (request.isIncorrect is true after a wrong password), then answer it:
    request.updatePassword("test123") // the text the user typed
    // request.cancel()               // or the user gave up
}
```

Passwords are never logged, sent in events or saved. PDFKit opens encrypted PDFs on every iOS
version. `isPasswordProtected` (and the 🔒 badge) stay on while an encrypted document is open.

## 10. Built-in UI

The viewer has its own UI around the pages, the same on Android and iOS:

| Part | Phone (< 600 pt wide) | Tablet (≥ 600 pt) |
|---|---|---|
| Top bar | brand and a ⋯ menu (zoom, fit, theme, go to page) | brand, upload, add signature, E-Materai, clear, pages, zoom, theme (scrolls sideways when it does not fit) |
| Bottom bar | upload, add signature, E-Materai, clear (scrolls sideways when labels are long) | – |
| Page indicator | floating "‹ 1 / 5 ›"; tap the number to go to a page | in the top bar |
| Thumbnails | strip above the bottom bar (hidden below 560 pt height) | sidebar |
| Status line | "Ready · 2 signatures", 🔒 badge, zoom (hidden below 420 pt height) | same |
| Empty state | title, text, upload button, and the error when loading failed | same |

`ui.layout` forces `.phone` or `.tablet`. Every part can be turned off:

```swift
PsdkConfig(
    ui: PsdkUiConfig(
        topbar: TopBarConfig(upload: false, themeToggle: false, brandText: "My App"),
        sidebar: SidebarConfig(thumbnails: false),
        statusbar: false
    )
)
```

With every `topbar` option off and no brand, logo or custom view, there is no top bar.
`topbar.customView` adds your own `UIView`; `topbar.logo` (`UIImage`) and `topbar.style`
(background, content color, height, padding) style the bar. `disabled: true` turns off the toolbar
buttons and all item editing.

**Pickers.** The add buttons and `openSignatureModal()` / `openEStampModal()` place a default item,
or show a list when options are given:

```swift
PsdkConfig(
    signatureOptions: [
        PickerOption(id: "director", label: "Director", image: .image(UIImage(named: "director-signature")!), group: "Internal"),
        PickerOption(id: "client", label: "Client", group: "External")
    ],
    estampOptions: [PickerOption(id: "stamp-10000", label: "E-Materai 10,000")],
    groupByCategory: true // "Group · option"; options without a group go under labels.defaultGroup
)
```

## 11. Theme, colors, font and labels

```swift
var colors = PsdkColors.light
colors.accent = UIColor(red: 0, green: 0.34, blue: 0.72, alpha: 1)
var labels = PsdkLabels.indonesian
labels.uploadBtn = "Pilih PDF"

PsdkConfig(
    theme: .system,            // .light (default), .dark or .system
    lightColors: colors,
    darkColors: .dark,
    typography: PsdkTypography(fontName: "Inter-Regular", baseFontSize: 16),
    labels: labels
)
```

- `PsdkColors.light` / `.dark` are the web colors adjusted for WCAG AA contrast; `.webLight` /
  `.webDark` are the web colors unchanged. There are 18 tokens (`background`, `surface`, `accent`,
  `danger`, `textPrimary`, …). Pages are always white. System sheets and menus follow the theme.
- The theme button switches between light and dark without sending an event.
- `PsdkLabels` holds every text (English by default, `.indonesian` for Bahasa Indonesia), including
  VoiceOver texts. Item labels in the result stay `"Signature"` and `"E-Materai"` in every language.

## 12. Upload button

The upload button (`topbar.upload`) opens the Files picker for PDFs. `onUpload` decides what
happens with the chosen file:

```swift
PsdkConfig(onUpload: { picked in
    // Example: only accept files up to 20 MB
    guard case let .file(url) = picked,
          let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
          size <= 20_000_000 else { return .cancel }
    return .proceed // or open another document instead: .replace(.bundle(name: "other.pdf"))
})
```

## 13. Loading overlay

```swift
viewer.showSkeleton(true, options: SkeletonOptions(backgroundOpacity: 0.3, blurRadius: 8))
// … send to the backend …
viewer.showSkeleton(false)
```

`SkeletonOptions(customView:)` replaces the spinner with your own view.

## 14. Page images

```swift
let page: UIImage? = await viewer.renderPage(1, scale: 2)               // pixels per PDF point
let withItems: UIImage? = await viewer.renderPageWithOverlay(1, scale: 2) // items drawn on top
```

Useful for previews or a confirmation screen. Images follow /Rotate like the viewer.

## 15. Screen protection

`secureScreen: true` covers the viewer with black while the screen is recorded or mirrored
(`UIScreen.isCaptured`). iOS gives apps no way to block regular screenshots.

## 16. Errors

`loadDocument` and `placeSignature` / `placeEStamp` throw `PsdkError`:

| Error | Meaning |
|---|---|
| `.sourceUnavailable` | file missing or unreadable, or the download failed |
| `.invalidURL` | not an allowed URL (e.g. HTTP without `allowInsecureHttp`) |
| `.invalidResponse` / `.httpStatus(code)` | the server's answer was not usable |
| `.documentTooLarge` / `.imageTooLarge` | above 100 MiB / 10 MiB |
| `.invalidDocument` | not a PDF or a damaged PDF |
| `.passwordCancelled` | the password prompt was cancelled |
| `.documentNotLoaded` / `.invalidPage` / `.destroyed` | no document / wrong page number / view destroyed |

`getPageSize` and `renderPage` return `nil` instead of throwing. After a failed load the empty state
shows a short message; with `logLevel: .debug` it also shows the error, and the SDK logs details
(subsystem `io.github.fvory.psdk`).

## 17. Lifecycle and restoring state

- With SwiftUI, keep the controller in `@StateObject` so the viewer lives as long as the screen.
- Call `destroy()` when a `PdfSignatureView` is no longer used: it closes the document, removes
  listeners and observers, and cancels an open password prompt.
- Rotation does not recreate the view on iOS, so items stay. To keep them across app launches, save
  `getSignatures()` yourself.

## 18. All options

| `PsdkConfig` | Default | See |
|---|---|---|
| `file` | `nil` | §3 |
| `allowInsecureHttp` | `false` | §3 |
| `scale` | `nil` (fit width) | §8 |
| `theme`, `lightColors`, `darkColors`, `typography` | `.light`, AA colors, system font | §11 |
| `disabled`, `disableDragging`, `disableDrag`, `disableResize` | `false` | §5 |
| `estampKeepAspectRatio` | `false` | §5 |
| `signatureOptions`, `estampOptions`, `groupByCategory` | empty, `false` | §10 |
| `defaultPosition` | `null` (centered) | §4 |
| `onUpload` | `nil` (open the picked file) | §12 |
| `lockScrollWhenPaginationLocked` | `false` | §8 |
| `secureScreen` | `false` | §15 |
| `labels` | English | §11 |
| `ui` | everything on | `topbar`, `sidebar.thumbnails`, `viewer.zoom`, `statusbar`, `passwordDialog`, `layout`, `haptics` (§10) |
| `logLevel` | `.error` | `.none`, `.error`, `.debug` (§16) |

Change options at runtime with `viewer.updateConfig { $0.disabled = true }`.

## 19. Platform differences

| | Android | iOS |
|---|---|---|
| UI toolkit | Compose and XML/View | UIKit (`PdfSignatureView`) and SwiftUI (`PdfSignatureViewer`) |
| State | `viewer.state` (`StateFlow`) | `PdfSignatureController` (`@Published`) |
| Events | `on<T>`, `events` (`SharedFlow`) | `on(.type)`, `eventsPublisher` (Combine), delegate |
| Screen protection | screenshots and recordings blocked | covered while recording or mirroring; iOS cannot block screenshots |
| Encrypted PDFs | Android 15+ built in, 12–14 with a system update, otherwise `psdk-pdfium` | always built in (PDFKit) |
| Restore after the app is ended | automatic | not needed for rotation; keep `getSignatures()` yourself across launches |
| Custom toolbar content | `customComponent` (composable) | `customView` (`UIView`) |
| Font | `fontFamily` | `typography` (font name and base size) |

Everything else (coordinates, JSON, events, options, built-in UI) is the same.

## 20. Building from source

```bash
scripts/test.sh           # unit tests, including the web SDK parity fixtures
scripts/test.sh example   # Example app UI tests: drag, delete, scrolling, toolbar, menu
```

`Example/` is the demo app (generate the project with `xcodegen` inside `Example/`), and
`Tests/PdfSignatureSDKTests/Parity/` holds the web SDK comparison fixtures shared with Android. The
SDK is a preview; the public API may still change before 1.0.0.
