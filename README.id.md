# PdfSignatureSDK untuk iOS

[![CI](https://github.com/FvorY/pdf-signature-sdk-ios/actions/workflows/ci.yml/badge.svg)](https://github.com/FvorY/pdf-signature-sdk-ios/actions/workflows/ci.yml)
![iOS 14+](https://img.shields.io/badge/iOS-14%2B-blue)
![License: MIT](https://img.shields.io/badge/license-MIT-green)

PDF viewer native iOS untuk menempatkan **tanda tangan** dan **E-Materai** pada dokumen. User bisa
menambah, menggeser, me-resize, mengunci, dan menghapus item. SDK mengembalikan posisi dalam PDF
point, sehingga payload yang sama dapat dikirim ke backend yang dipakai SDK web dan Android.

SDK Android dan iOS memakai konsep inti yang sama: sumber PDF, penempatan item, event, koordinat,
output JSON/Codable, dan proses signing di backend. Perbedaannya hanya pada integrasi UI sesuai
platform.

> Preview: viewer dan Example app sudah dapat digunakan, tetapi API publik masih bisa berubah
> sebelum rilis 1.0.0.

Bahasa dan dokumentasi lengkap:

- [English README](README.md)
- [Dokumentasi Bahasa Indonesia](DOCUMENTATION.id.md)
- [English documentation](DOCUMENTATION.en.md)

## Fitur

- Render dengan PDFKit, pagination, thumbnail, zoom, fit-to-screen, dan fit-to-width.
- Penempatan tanda tangan dan E-Materai dengan drag, resize, hapus, dan kunci per item.
- API Swift, event handler, publisher Combine, dan output `Codable`.
- `PdfSignatureView` (`UIView`) untuk UIKit dan wrapper untuk SwiftUI.
- Toolbar bawaan untuk ponsel dan tablet (upload, tambah, hapus semua, halaman, zoom, tema), indikator
  halaman, thumbnail, status bar, dan empty state, sama seperti SDK Android.
- Tema terang, gelap, dan sistem dengan 18 token warna, font dan label kustom (Inggris dan Indonesia).
- PDF berpassword (dialog bawaan), tombol upload, skeleton loading, VoiceOver, dan secure screen.
- Tidak memiliki dependensi runtime pihak ketiga.

## Persyaratan

| Komponen | Persyaratan |
|---|---|
| iOS | 14.0+ |
| Xcode | 16+ |
| Swift | 5.9+ |
| UI | UIKit atau SwiftUI |

## Instalasi

### Swift Package Manager

Di Xcode, pilih **File → Add Package Dependencies…**, lalu masukkan:

```text
https://github.com/FvorY/pdf-signature-sdk-ios
```

Pilih **Branch: main** karena belum ada tag rilis stabil. Di `Package.swift` bisa ditulis:

```swift
.package(url: "https://github.com/FvorY/pdf-signature-sdk-ios", branch: "main")
```

### CocoaPods

```ruby
pod 'PdfSignatureSDK', :git => 'https://github.com/FvorY/pdf-signature-sdk-ios.git'
```

## Mulai cepat: UIKit

Di contoh, `pdfURL` dan `pdfData` mewakili nilai milikmu sendiri; selebihnya adalah API SDK.

`PdfSignatureView` adalah `UIView`, jadi bisa langsung ditambahkan ke screen UIKit:

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

Untuk membuka dokumen setelah view dibuat:

```swift
Task {
    try await viewer.loadDocument(.file(pdfURL))
}
```

## Mulai cepat: SwiftUI

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

Controller menyediakan `currentPage`, `totalPages`, `currentScale`, `signatures`, `isLoaded`, dan
`isPasswordProtected` secara reaktif.

## Sumber PDF

```swift
.file(pdfURL)
.data(pdfData)
.remote(URL(string: "https://example.com/document.pdf")!)
.remote(url, headers: ["Authorization": "Bearer <token>"])
.bundle(name: "example.pdf")
```

URL PDF remote wajib HTTPS secara default. HTTP hanya boleh diaktifkan untuk endpoint lama yang
tepercaya:

```swift
let config = PsdkConfig(allowInsecureHttp: true)
```

Download dibatasi 100 MiB dan redirect divalidasi ulang. SDK tidak melakukan signing kriptografis;
proses signing dokumen dan pemeriksaan integritas tetap menjadi tanggung jawab backend.

## Menempatkan item dan mengirim hasil

```swift
let id = try viewer.placeSignature(
    PlaceOptions(
        x: 72,
        y: 680,
        page: 1,
        label: "Direktur",
        width: 140,
        height: 60
    )
)

try viewer.placeEStamp(PlaceOptions(x: 420, y: 700, page: 1))

let items = viewer.getSignatures()
let json = try JSONEncoder().encode(items)
viewer.removeSignature(id)
```

Koordinat memakai PDF point (1/72 inci), dengan pojok kiri-atas halaman sebagai `(0, 0)` dan
sumbu Y ke bawah. `page` dimulai dari 1. Ukuran A4 umumnya 595 × 842 point. `SignatureItem` juga
memiliki `yFromBottom(pageHeight)` untuk library PDF yang memakai titik awal kiri-bawah.

## Event dan state

```swift
let subscription = viewer.on(.signaturePlaced) { event in
    if case let .signaturePlaced(item) = event {
        print(item) // kirim ini ke backend
    }
}

// Panggil saat screen tidak lagi membutuhkan listener.
viewer.off(subscription)
```

Event yang tersedia antara lain `documentLoaded`, `pageChanged`, `signaturePlaced`, `eStampPlaced`,
`signatureMoved`, `signatureRemoved`, `signaturesCleared`, dan `passwordRequested`. Pengguna UIKit
juga dapat memakai `PdfSignatureViewDelegate`; pengguna Combine dapat mengumpulkan
`eventsPublisher`.

## Konfigurasi dan keamanan

`PsdkConfig` mengatur tema, label, picker, zoom awal, kunci item, layout UI, warna, tipografi, dan
`secureScreen`. Set `secureScreen: true` untuk menutup viewer saat layar direkam atau di-mirror; iOS
tidak menyediakan cara bagi aplikasi untuk memblokir screenshot biasa.

Untuk PDF berpassword, gunakan dialog bawaan atau tangani event sendiri:

```swift
viewer.on(.passwordRequested) { event in
    if case let .passwordRequested(request) = event {
        // Tampilkan dialog sendiri, lalu jawab:
        request.updatePassword("test123") // teks yang diketik user
        // request.cancel()               // atau user menyerah
    }
}
```

Password tidak dimasukkan ke deskripsi event atau state viewer.

## Struktur project dan test

| Path | Isi |
|---|---|
| `Sources/PdfSignatureSDK` | Library iOS |
| `Tests/PdfSignatureSDKTests` | Unit test dan fixture paritas web |
| `Example/` | Demo app dan UI test |
| `parity/` | Sumber fixture paritas |
| `scripts/test.sh` | Script untuk menjalankan test |

```bash
scripts/test.sh
scripts/test.sh example
```

## Lisensi

[MIT](LICENSE)
