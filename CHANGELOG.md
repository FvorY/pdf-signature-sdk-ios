# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the
project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- `PsdkConfig.defaultPosition` (`PlacementPosition(x:y:)`): the add buttons and pickers place new items
  at a fixed top-left position (kept inside the page) instead of the page center, so no dragging is needed.
  `placeSignature` / `placeEStamp` are unchanged.
- `PsdkConfig.askPositionOnAdd`: the add buttons open a built-in dialog with X and Y (PDF points) before the
  item is placed. Both fields empty places it at `defaultPosition` or the page center; Cancel adds nothing.
  Off by default. New `PsdkLabels` texts: `positionModalTitle`, `positionModalDesc`, `positionX`, `positionY`,
  `positionPageSize`, `positionInvalid`, `placeBtn`.
- Built-in viewer UI matching the Android SDK: phone layout (top bar with ⋯ menu, scrollable bottom
  bar, floating "‹ 1 / 5 ›" page indicator, thumbnail strip) and tablet layout (web-style toolbar,
  thumbnail sidebar), status line with item count, zoom and 🔒 badge, empty state with upload button
  and load error, go-to-page dialog, built-in password dialog.
- Themes: `theme` (`.light` default, `.dark`, `.system` following the system), `lightColors` /
  `darkColors` with the Android SDK's 18 tokens (`PsdkColors.light`, `.dark`, `.webLight`,
  `.webDark`), `typography`. System sheets and menus follow the theme.
- `PsdkLabels` with every text of the Android SDK (incl. VoiceOver texts) and `.indonesian`.
- Upload button with the Files picker and `onUpload` (`UploadDecision`).
- `ui.topbar` (`upload`, `signature`, `eStamp`, `pagination`, `paginationInput`, `zoom`,
  `themeToggle`, `customView`, `logo`, `brandText`, `style`), `ui.sidebar.thumbnails`,
  `ui.viewer.zoom`, `ui.statusbar`, `ui.passwordDialog`, `ui.layout`, `ui.haptics` are applied.
- `estampKeepAspectRatio`, haptics, `logLevel` (os.Logger), `SkeletonOptions(customView:)`.
- VoiceOver actions per item: move, bigger/smaller, delete.
- `getPageSize(_:)` (same name as Android); `PsdkError.passwordCancelled` and `.destroyed`.
- Tests that compile the guide's code samples, Chrome rules, theme, password cancel, aspect ratio;
  UI tests for the toolbar picker and the ⋯ menu.
- Web SDK parity tests with the same fixtures as the Android SDK (`Tests/.../Parity`): page sizes and
  item positions for `sample.pdf` and `geometry.pdf` (/Rotate 0/90/180/270, CropBox, MediaBox offset).
- Example app is a working demo (bundled PDF, pickers, locks, JSON) with UI tests for drag, delete
  and scrolling under the overlay. CI runs them.
- VoiceOver: one element per visible item with a Delete action.
- `lockScrollWhenPaginationLocked` is applied.
- Swift package skeleton (`PdfSignatureSDK`, iOS 14+), privacy manifest, unit test target.
- Preview `PdfSignatureView` UIKit API, SwiftUI controller/wrapper, PDF loading, pagination,
  zoom, password events, signature placement and interactive item overlay.
- Remote PDF hardening with HTTPS-by-default, redirect validation and bounded input sizes.
- Asynchronous signature/E-Materai image loading from URL, Base64 or `UIImage`, including automatic
  height adjustment and `signatureMoved` parity behavior.
- CocoaPods podspec.
- English and Indonesian usage guides (`DOCUMENTATION.en.md`, `DOCUMENTATION.id.md`).
- Example app generated with XcodeGen.
- GitHub Actions: SwiftLint, unit tests, Example build, `pod lib lint`, tag release.

### Fixed
- The item overlay took every touch, so the PDF could not be scrolled or zoomed. Touches now only
  go to the overlay when they start on an item.
- Items did not follow the page while scrolling or zooming, and only the current page's items were
  drawn. The overlay now redraws on scroll and zoom and draws items on every visible page.
- Items on /Rotate 90/180/270 pages were drawn in the wrong place; `renderPage` ignored /Rotate.
- Scrolling never changed the current page (`pageChanged` was never sent for scrolling).
- Tapping the delete button did nothing; the delete and resize controls overlapped on small items.
- `once` listeners could fire more than once; downloads kept their URL session alive.
- Local files were read on the main thread.
- The SDK did not build with CocoaPods (`Bundle.module` only exists with Swift Package Manager).
- SwiftLint failures that made CI fail.

### Changed
- **Breaking:** `PsdkConfig` follows the Android SDK: parameter order, `lightColors` / `darkColors`
  instead of `colors`, default theme `.light`, and `ui` nested as `topbar` / `sidebar` / `viewer`.
  `PsdkColors` uses `UIColor` tokens. `PsdkLabels` is changed by assigning its properties.
- `loadDocument` waits for the password of an encrypted PDF and throws `.passwordCancelled` when the
  prompt is cancelled (before it returned right away). `isPasswordProtected` stays `true` while an
  encrypted document is open.
- `pageSize(_:)` is deprecated; use `getPageSize(_:)`.
- The guides (EN/ID) are rewritten with the same 20 sections as the Android guides.
- Placement matches the web SDK: items are centered unless both `x` and `y` are given, E-Materai is
  always labelled "E-Materai", a signature without a label is "Signature" (`labels` only changes
  picker titles), and ids end in 5 random base-36 characters.
- `pageSize` rounds like the web SDK (A4 is 594.67 × 841.33).
- `PsdkConfig.scale` is optional; `nil` (default) fits the page width, like the Android SDK.
- `pdfViewPageChanged(_:)` is no longer public.

