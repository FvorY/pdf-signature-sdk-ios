# PdfSignatureSDK untuk iOS

[![CI](https://github.com/FvorY/pdf-signature-sdk-ios/actions/workflows/ci.yml/badge.svg)](https://github.com/FvorY/pdf-signature-sdk-ios/actions/workflows/ci.yml)
![iOS 14+](https://img.shields.io/badge/iOS-14%2B-blue)
![License: MIT](https://img.shields.io/badge/license-MIT-green)

PDF viewer native iOS (Swift). Dengan SDK ini, user bisa menaruh, menggeser, me-resize, dan
menghapus kotak **tanda tangan** dan **E-Materai** di dokumen. Posisi dikembalikan dalam
**PDF point**, sama persis dengan web SDK
[`pdf-signature-esign-sdk`](https://www.npmjs.com/package/pdf-signature-esign-sdk) v1.1.2,
sehingga backend yang sama bisa langsung menyelesaikan proses tanda tangan.

> 🚧 **Preview.** API viewer sudah dapat digunakan, tetapi API publik masih dalam tahap
> stabilisasi dan belum merupakan rilis 1.0.0.

English: [README.md](README.md)

Dokumentasi: [DOCUMENTATION.id.md](DOCUMENTATION.id.md) · [English documentation](DOCUMENTATION.en.md)

## Fitur

- Menampilkan PDF multi-halaman dengan zoom, pagination, fit-to-screen, dan fit-to-width.
- Menambahkan, menggeser, me-resize, menghapus, dan mengunci tanda tangan atau E-Materai.
- Menghasilkan koordinat PDF point yang dapat langsung dikirim ke backend.
- Mendukung PDF ber-password, event, konfigurasi label, kunci item, dan secure screen
  (opsi tema, warna, dan toolbar belum diterapkan).
- Dapat dipasang langsung pada UIKit sebagai `PdfSignatureView` (`UIView`) atau dipakai melalui SwiftUI.

## Instalasi

**Swift Package Manager.** Di Xcode buka File → Add Package Dependencies…, tempel
`https://github.com/FvorY/pdf-signature-sdk-ios`, lalu pilih *Branch: main* (belum ada tag rilis).

```swift
.package(url: "https://github.com/FvorY/pdf-signature-sdk-ios", branch: "main")
```

**CocoaPods:** `pod 'PdfSignatureSDK', :git => 'https://github.com/FvorY/pdf-signature-sdk-ios.git'`

Contoh UIKit, daftar API, event, password PDF, format koordinat, dan konfigurasi lengkap tersedia di [DOCUMENTATION.id.md](DOCUMENTATION.id.md).

## Sistem koordinat

- Satuan: PDF point (1/72 inci). Kertas A4 = 595 × 842 pt.
- Titik nol: pojok **kiri-atas** halaman. Sumbu Y mengarah ke bawah.
- `x, y` adalah pojok kiri-atas item, sama dengan web SDK.

## Pemakaian

```swift
import PdfSignatureSDK

let viewer = PdfSignatureView(config: PsdkConfig(file: .file(pdfURL)))
view.addSubview(viewer)

viewer.on(.signaturePlaced) { event in print(event) }

// Nanti, kirim posisi ke backend:
let json = try JSONEncoder().encode(viewer.getSignatures())
```

## Menjalankan test

```bash
scripts/test.sh
```

## Keamanan sumber remote

URL PDF remote wajib menggunakan HTTPS secara default. Untuk endpoint HTTP lama yang tepercaya
saja, aktifkan secara eksplisit dengan `PsdkConfig(allowInsecureHttp: true)`. Redirect divalidasi
kembali dan input PDF dibatasi 100 MiB. Penempatan tanda tangan hanya menghasilkan koordinat;
proses signing kriptografis dan integritas dokumen tetap harus ditegakkan oleh backend.

## Struktur project

| Path | Isi |
|---|---|
| `Sources/PdfSignatureSDK` | Library utama |
| `Tests/PdfSignatureSDKTests` | Unit test |
| `Example/` | Aplikasi demo (`project.yml` → `PdfSignatureExample.xcodeproj` hasil generate) |
| `parity/` | Fixture untuk membandingkan output dengan web SDK |
| `scripts/test.sh` | Menjalankan test di simulator iPhone pertama yang tersedia |

## Kontribusi

Lihat [CONTRIBUTING.md](CONTRIBUTING.md).

## Lisensi

[MIT](LICENSE)
