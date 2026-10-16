# PdfSignatureSDK untuk iOS — Panduan

SDK ini menampilkan PDF dan memungkinkan user menaruh **tanda tangan** dan **E-Materai** di atasnya.
Posisi dikembalikan dalam PDF point, dengan format JSON yang sama dengan web SDK
[`pdf-signature-esign-sdk`](https://www.npmjs.com/package/pdf-signature-esign-sdk) 1.1.2, sehingga
satu backend bisa menyelesaikan tanda tangan untuk web, Android, dan iOS.

[Panduan SDK Android](https://github.com/FvorY/pdf-signature-sdk-android/blob/main/DOCUMENTATION.id.md)
memakai bagian yang sama. English: [DOCUMENTATION.en.md](DOCUMENTATION.en.md).

1. [Persyaratan dan instalasi](#1-persyaratan-dan-instalasi)
2. [Menampilkan viewer](#2-menampilkan-viewer)
3. [Sumber PDF](#3-sumber-pdf)
4. [Menaruh item](#4-menaruh-item)
5. [Mengedit di layar](#5-mengedit-di-layar)
6. [Mengambil hasil](#6-mengambil-hasil)
7. [Event dan state](#7-event-dan-state)
8. [Halaman dan zoom](#8-halaman-dan-zoom)
9. [PDF berpassword](#9-pdf-berpassword)
10. [UI bawaan](#10-ui-bawaan)
11. [Tema, warna, font, dan label](#11-tema-warna-font-dan-label)
12. [Tombol upload](#12-tombol-upload)
13. [Overlay loading](#13-overlay-loading)
14. [Gambar halaman](#14-gambar-halaman)
15. [Perlindungan layar](#15-perlindungan-layar)
16. [Error](#16-error)
17. [Lifecycle](#17-lifecycle)
18. [Semua opsi](#18-semua-opsi)
19. [Perbedaan platform](#19-perbedaan-platform)
20. [Build dari source](#20-build-dari-source)

## 1. Persyaratan dan instalasi

| | Minimum | Catatan |
|---|---|---|
| iOS | 14.0 | |
| Xcode / Swift | 16 / 5.9 | |
| Instalasi | Swift Package Manager atau CocoaPods | keduanya dicek di CI (`pod lib lint`, Example app) |
| Dependensi | tidak ada | hanya `UIKit`, `PDFKit`, dan `Combine` dari Apple |

**Swift Package Manager.** Di Xcode pilih **File → Add Package Dependencies…**, masukkan
`https://github.com/FvorY/pdf-signature-sdk-ios`, lalu pilih **Branch: main** (belum ada tag
rilis). Di `Package.swift`:

```swift
.package(url: "https://github.com/FvorY/pdf-signature-sdk-ios", branch: "main")
```

**CocoaPods.**

```ruby
pod 'PdfSignatureSDK', :git => 'https://github.com/FvorY/pdf-signature-sdk-ios.git'
```

Lalu jalankan `pod install` dan buka `.xcworkspace`.

## 2. Menampilkan viewer

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

`PdfSignatureController` mem-publish `currentPage`, `totalPages`, `currentScale`, `signatures`,
`isLoaded`, dan `isPasswordProtected`, serta menyediakan viewer di `controller.view` untuk semua
method di bawah.

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

Untuk membuka dokumen belakangan, buat view tanpa `file` lalu panggil
`try await viewer.loadDocument(.file(url))`. View menampilkan picker dan dialognya dari view
controller terdekat, jadi harus berada di dalam view controller.

## 3. Sumber PDF

```swift
.file(url)                                   // file lokal, dibaca di luar main thread
.data(pdfData)
.bundle(name: "contoh.pdf")                  // bundle aplikasi (atau bundle: bundleLain)
.remote(url, headers: ["Authorization": "Bearer …"])
```

PDF dan gambar remote wajib HTTPS. `PsdkConfig(allowInsecureHttp: true)` mengizinkan HTTP hanya
untuk server lama yang tepercaya. Download mengikuti maksimal lima redirect yang divalidasi, header
dibuang bila host berubah, dan ukurannya dibatasi 100 MiB (PDF) serta 10 MiB (gambar).

## 4. Menaruh item

```swift
let signatureID = try viewer.placeSignature(PlaceOptions(
    x: 72, y: 680, page: 1, label: "Direktur",
    image: .url(URL(string: "https://example.com/ttd.png")!), width: 140
))
let stampID = try viewer.placeEStamp(PlaceOptions(x: 420, y: 700, page: 1))
```

| `PlaceOptions` | Arti | Default |
|---|---|---|
| `page` | Halaman, mulai dari 1 | halaman aktif |
| `x`, `y` | Pojok kiri-atas dalam PDF point | di tengah, kecuali keduanya diisi |
| `width`, `height` | Ukuran dalam PDF point | 160 × 48 (tanda tangan), 80 × 80 (E-Materai) |
| `label` | Teks tanda tangan | `"Signature"`; E-Materai selalu `"E-Materai"` |
| `image` | `.url(URL)`, `.base64(String)`, `.image(UIImage)`, atau `PsdkImage(string:)` | tidak ada |
| `disableDrag`, `disableResize`, `disableDragging`, `locked` | Kunci untuk item ini (§5) | `false` |

Tanpa `height`, item bergambar mengikuti rasio gambar setelah gambarnya termuat (event
`signatureMoved` melaporkan ukuran barunya), sama seperti web SDK.

**Koordinat**: PDF point (1/72 inci), titik nol di pojok kiri-atas halaman seperti yang tampil
(setelah /Rotate), sumbu Y ke bawah. A4 sekitar 595 × 842. `getPageSize(page)` memberi ukuran tiap
halaman, dibulatkan seperti web SDK (A4 menjadi 594,67 × 841,33).

Tombol tambah dan picker di UI bawaan dijelaskan di §10.

## 5. Mengedit di layar

- Geser item untuk memindahkan; tarik pegangan di pojok kanan-bawah untuk resize (minimal 20 pt);
  tap tombol di pojok kanan-atas untuk menghapus. Item tetap berada di dalam halamannya. Sentuhan di
  luar item tetap men-scroll dan zoom PDF.
- Kunci mengikuti web SDK: `disableDrag` menahan geser, `disableResize` menahan resize,
  `disableDragging` dan `locked` menahan keduanya. Tombol hapus tetap berfungsi pada item yang
  dikunci; hanya `disabled` yang mematikannya. Kunci yang sama tersedia untuk semua item di `PsdkConfig`.
- `estampKeepAspectRatio: true` menjaga rasio lebar/tinggi E-Materai saat di-resize.
- `ui.haptics` memberi getaran singkat saat item mulai digeser atau dihapus.
- VoiceOver membacakan tiap item ("Signature, halaman 1") dan menyediakan aksi geser,
  perbesar/perkecil, dan hapus.

## 6. Mengambil hasil

```swift
let items: [SignatureItem] = viewer.getSignatures()
let diHalaman2 = viewer.getSignaturesByPage(2)
let json = try JSONEncoder().encode(items) // field sama dengan web SDK
```

```json
{"id":"signature-1760600000000-k3x9a","type":"signature","x":72,"y":680,"page":1,"label":"Direktur",
 "width":140,"height":48,"disableDrag":false,"disableDragging":false,"disableResize":false,"locked":false}
```

`SignatureItem` bersifat `Codable`. `yFromBottom(pageHeight:)` mengubah `y` untuk library PDF yang
mengukur dari pojok kiri-bawah. `removeSignature(id)` dan `clearSignatures()` menghapus item.

## 7. Event dan state

```swift
let subscription = viewer.on(.signaturePlaced) { event in
    if case let .signaturePlaced(item) = event { kirim(item) }
}
viewer.once(.documentLoaded) { event in print(event) }
viewer.off(subscription)
```

| Event | Data | Kapan |
|---|---|---|
| `.documentLoaded` | `totalPages` | dokumen terbuka |
| `.pageChanged` | `page`, `total`, `source` (`.scroll` atau `.api`) | halaman aktif berubah |
| `.signaturePlaced` / `.eStampPlaced` | `SignatureItem` | item ditaruh |
| `.signatureMoved` | `SignatureItem` | item digeser atau di-resize (juga setelah gambar mengatur tingginya) |
| `.signatureRemoved` | `id` | item dihapus |
| `.signaturesCleared` | – | semua item dihapus, juga saat dokumen baru dibuka |
| `.passwordRequested` | `PasswordRequest` (`isIncorrect`, `updatePassword(_:)`, `cancel()`) | password dibutuhkan (§9) |

Handler berjalan di main thread. Pengguna Combine bisa berlangganan `viewer.eventsPublisher`; kode
UIKit bisa memasang `viewer.delegate`. State view ada di `currentPage`, `totalPages`,
`currentScale`, `isLoaded`, `isLoading`, `isPaginationLocked`, dan `isPasswordProtected`; SwiftUI
mendapatkannya dari `PdfSignatureController`.

## 8. Halaman dan zoom

```swift
viewer.nextPage(); viewer.prevPage(); viewer.goToPage(3) // false bila tidak bisa
viewer.setPaginationLocked(true) // mengunci tombol, input halaman, thumbnail, dan goToPage
await viewer.setScale(1.5)       // 0,25–4,0
await viewer.fitToScreen(); await viewer.fitToWidth()
```

Tanpa `PsdkConfig(scale:)`, lebar halaman menyesuaikan view. User bisa pinch dan double-tap untuk
zoom (`ui.viewer.zoom = false` mematikannya). `lockScrollWhenPaginationLocked: true` juga menahan
scroll saat pagination dikunci (default mati, sama seperti web SDK).

## 9. PDF berpassword

`loadDocument` menunggu sampai password membuka dokumen, dan melempar `PsdkError.passwordCancelled`
bila prompt dibatalkan. Dialog bawaan (`ui.passwordDialog`, default nyala) meminta password; event
`.passwordRequested` tetap dikirim, jadi bisa diganti dialog sendiri:

```swift
var ui = PsdkUiConfig()
ui.passwordDialog = false
let viewer = PdfSignatureView(config: PsdkConfig(ui: ui))
viewer.on(.passwordRequested) { event in
    guard case let .passwordRequested(request) = event else { return }
    tampilkanDialog(salah: request.isIncorrect, onOK: request.updatePassword, onBatal: request.cancel)
}
```

Password tidak pernah di-log, dikirim lewat event, atau disimpan. PDFKit bisa membuka PDF
terenkripsi di semua versi iOS. `isPasswordProtected` (dan badge 🔒) tetap aktif selama dokumen
terenkripsi terbuka.

## 10. UI bawaan

Viewer punya UI sendiri di sekitar halaman, sama di Android dan iOS:

| Bagian | Ponsel (lebar < 600 pt) | Tablet (≥ 600 pt) |
|---|---|---|
| Top bar | brand dan menu ⋯ (zoom, fit, tema, ke halaman) | brand, upload, tambah tanda tangan, E-Materai, hapus semua, halaman, zoom, tema (bisa digeser bila tidak muat) |
| Bottom bar | upload, tambah tanda tangan, E-Materai, hapus semua (bisa digeser bila label panjang) | – |
| Indikator halaman | "‹ 1 / 5 ›" mengambang; tap angkanya untuk lompat halaman | di top bar |
| Thumbnail | strip di atas bottom bar (disembunyikan bila tinggi < 560 pt) | sidebar |
| Status bar | "Siap · 2 tanda tangan", badge 🔒, zoom (disembunyikan bila tinggi < 420 pt) | sama |
| Empty state | judul, teks, tombol upload, dan error bila gagal membuka | sama |

`ui.layout` memaksa `.phone` atau `.tablet`. Semua bagian bisa dimatikan:

```swift
PsdkConfig(
    ui: PsdkUiConfig(
        topbar: TopBarConfig(upload: false, themeToggle: false, brandText: "Aplikasiku"),
        sidebar: SidebarConfig(thumbnails: false),
        statusbar: false
    )
)
```

Bila semua opsi `topbar` mati dan tidak ada brand, logo, atau view kustom, top bar tidak tampil.
`topbar.customView` menambah `UIView` sendiri; `topbar.logo` (`UIImage`) dan `topbar.style` (latar,
warna isi, tinggi, padding) mengatur tampilannya. `disabled: true` mematikan tombol toolbar dan semua
pengeditan item.

**Picker.** Tombol tambah serta `openSignatureModal()` / `openEStampModal()` menaruh item default,
atau menampilkan daftar bila opsi diisi:

```swift
PsdkConfig(
    signatureOptions: [
        PickerOption(id: "direktur", label: "Direktur", image: .image(ttdDirektur), group: "Internal"),
        PickerOption(id: "klien", label: "Klien", group: "Eksternal")
    ],
    estampOptions: [PickerOption(id: "materai-10000", label: "Materai 10.000")],
    groupByCategory: true // "Grup · opsi"; opsi tanpa grup masuk labels.defaultGroup
)
```

## 11. Tema, warna, font, dan label

```swift
var colors = PsdkColors.light
colors.accent = UIColor(red: 0, green: 0.34, blue: 0.72, alpha: 1)
var labels = PsdkLabels.indonesian
labels.uploadBtn = "Pilih PDF"

PsdkConfig(
    theme: .system,            // .light (default), .dark, atau .system
    lightColors: colors,
    darkColors: .dark,
    typography: PsdkTypography(fontName: "Inter-Regular", baseFontSize: 16),
    labels: labels
)
```

- `PsdkColors.light` / `.dark` adalah warna web yang disesuaikan agar kontrasnya lolos WCAG AA;
  `.webLight` / `.webDark` adalah warna web asli. Ada 18 token (`background`, `surface`, `accent`,
  `danger`, `textPrimary`, …). Halaman PDF selalu putih. Sheet dan menu sistem ikut tema.
- Tombol tema berpindah antara terang dan gelap tanpa mengirim event.
- `PsdkLabels` memuat semua teks (default Inggris, `.indonesian` untuk Bahasa Indonesia), termasuk
  teks VoiceOver. Label item di hasil tetap `"Signature"` dan `"E-Materai"` di semua bahasa.

## 12. Tombol upload

Tombol upload (`topbar.upload`) membuka picker Files untuk PDF. `onUpload` menentukan apa yang
terjadi dengan file pilihan:

```swift
PsdkConfig(onUpload: { dipilih in
    guard await diizinkan(dipilih) else { return .cancel }
    return .proceed // atau .replace(sumberLain)
})
```

## 13. Overlay loading

```swift
viewer.showSkeleton(true, options: SkeletonOptions(backgroundOpacity: 0.3, blurRadius: 8))
// … kirim ke backend …
viewer.showSkeleton(false)
```

`SkeletonOptions(customView:)` mengganti spinner dengan view sendiri.

## 14. Gambar halaman

```swift
let halaman: UIImage? = await viewer.renderPage(1, scale: 2)                // piksel per PDF point
let denganItem: UIImage? = await viewer.renderPageWithOverlay(1, scale: 2)  // item digambar di atasnya
```

Berguna untuk pratinjau atau layar konfirmasi. Gambar mengikuti /Rotate seperti viewer.

## 15. Perlindungan layar

`secureScreen: true` menutup viewer dengan warna hitam saat layar direkam atau di-mirror
(`UIScreen.isCaptured`). iOS tidak menyediakan cara bagi aplikasi untuk memblokir screenshot biasa.

## 16. Error

`loadDocument` dan `placeSignature` / `placeEStamp` melempar `PsdkError`:

| Error | Arti |
|---|---|
| `.sourceUnavailable` | file tidak ada atau tidak terbaca, atau download gagal |
| `.invalidURL` | URL tidak diizinkan (mis. HTTP tanpa `allowInsecureHttp`) |
| `.invalidResponse` / `.httpStatus(code)` | jawaban server tidak bisa dipakai |
| `.documentTooLarge` / `.imageTooLarge` | lebih dari 100 MiB / 10 MiB |
| `.invalidDocument` | bukan PDF atau PDF rusak |
| `.passwordCancelled` | prompt password dibatalkan |
| `.documentNotLoaded` / `.invalidPage` / `.destroyed` | belum ada dokumen / nomor halaman salah / view sudah dihancurkan |

`getPageSize` dan `renderPage` mengembalikan `nil` alih-alih melempar error. Setelah gagal membuka,
empty state menampilkan pesan singkat; dengan `logLevel: .debug` juga menampilkan error-nya, dan
SDK menulis detail ke log (subsystem `io.github.fvory.psdk`).

## 17. Lifecycle

- Dengan SwiftUI, simpan controller di `@StateObject` supaya viewer hidup selama layar ada.
- Panggil `destroy()` bila `PdfSignatureView` tidak dipakai lagi: dokumen ditutup, listener dan
  observer dilepas, dan prompt password yang masih terbuka dibatalkan.
- Di iOS rotasi tidak membuat ulang view, jadi item tetap ada. Untuk menyimpannya antar-peluncuran
  aplikasi, simpan `getSignatures()` sendiri.

## 18. Semua opsi

| `PsdkConfig` | Default | Lihat |
|---|---|---|
| `file` | `nil` | §3 |
| `allowInsecureHttp` | `false` | §3 |
| `scale` | `nil` (fit width) | §8 |
| `theme`, `lightColors`, `darkColors`, `typography` | `.light`, warna AA, font sistem | §11 |
| `disabled`, `disableDragging`, `disableDrag`, `disableResize` | `false` | §5 |
| `estampKeepAspectRatio` | `false` | §5 |
| `signatureOptions`, `estampOptions`, `groupByCategory` | kosong, `false` | §10 |
| `onUpload` | `nil` (buka file pilihan) | §12 |
| `lockScrollWhenPaginationLocked` | `false` | §8 |
| `secureScreen` | `false` | §15 |
| `labels` | Inggris | §11 |
| `ui` | semua nyala | `topbar`, `sidebar.thumbnails`, `viewer.zoom`, `statusbar`, `passwordDialog`, `layout`, `haptics` (§10) |
| `logLevel` | `.error` | `.none`, `.error`, `.debug` (§16) |

Ubah opsi saat berjalan dengan `viewer.updateConfig { $0.disabled = true }`.

## 19. Perbedaan platform

| | Android | iOS |
|---|---|---|
| UI toolkit | Compose dan XML/View | UIKit (`PdfSignatureView`) dan SwiftUI (`PdfSignatureViewer`) |
| State | `viewer.state` (`StateFlow`) | `PdfSignatureController` (`@Published`) |
| Event | `on<T>`, `events` (`SharedFlow`) | `on(.type)`, `eventsPublisher` (Combine), delegate |
| Perlindungan layar | screenshot dan rekaman diblokir | ditutup saat direkam atau di-mirror; iOS tidak bisa memblokir screenshot |
| PDF terenkripsi | Android 15+ bawaan, 12–14 dengan pembaruan sistem, selain itu `psdk-pdfium` | selalu bawaan (PDFKit) |
| Pemulihan setelah aplikasi dihentikan | otomatis | tidak perlu untuk rotasi; simpan `getSignatures()` sendiri antar-peluncuran |
| Konten kustom di toolbar | `customComponent` (composable) | `customView` (`UIView`) |
| Font | `fontFamily` | `typography` (nama font dan ukuran dasar) |

Selebihnya (koordinat, JSON, event, opsi, UI bawaan) sama.

## 20. Build dari source

```bash
scripts/test.sh           # unit test, termasuk fixture paritas web SDK
scripts/test.sh example   # UI test Example app: geser, hapus, scroll, toolbar, menu
```

`Example/` adalah aplikasi demo (generate project dengan `xcodegen` di dalam `Example/`), dan
`Tests/PdfSignatureSDKTests/Parity/` berisi fixture pembanding web SDK yang sama dengan Android. SDK
masih preview; API publik masih bisa berubah sebelum 1.0.0.
