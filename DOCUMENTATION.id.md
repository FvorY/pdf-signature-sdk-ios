# PdfSignatureSDK iOS

Dokumen ini menjelaskan pemasangan dan penggunaan `PdfSignatureSDK` di aplikasi iOS. SDK menyediakan viewer PDF dan overlay untuk tanda tangan serta E-Materai. Proses tanda tangan digital tetap dilakukan oleh backend aplikasi.

## Fitur

- Menampilkan PDF dari file lokal, `Data`, bundle aplikasi, atau URL remote HTTPS.
- Menampilkan dokumen multi-halaman dengan pagination, zoom, fit-to-screen, dan fit-to-width.
- Menambahkan kotak tanda tangan pada halaman tertentu.
- Menambahkan kotak E-Materai pada halaman tertentu.
- Menggeser, resize, menghapus, atau mengunci item.
- Menyediakan picker untuk memilih peran tanda tangan dan jenis E-Materai.
- Mengembalikan koordinat PDF point yang kompatibel dengan web SDK.
- Mendukung PDF yang dilindungi password.
- Menampilkan skeleton/loading overlay saat aplikasi memproses upload atau signing.
- Menyediakan event untuk document loaded, perubahan halaman, item ditempatkan/digeser/dihapus, dan permintaan password.
- Menyediakan konfigurasi label bahasa, kunci item, skala awal, dan secure screen.
- Dapat dipakai langsung di UIKit melalui `UIView`, atau di SwiftUI melalui `PdfSignatureViewer`.

## Persyaratan

- iOS 14 atau lebih baru
- Xcode 16 atau lebih baru
- Swift 5.9 atau lebih baru
- Framework Apple: `UIKit` dan `PDFKit`

## Instalasi

### Swift Package Manager

Di Xcode pilih **File → Add Package Dependencies…**, masukkan URL berikut, lalu pilih aturan **Branch: main**:

```text
https://github.com/FvorY/pdf-signature-sdk-ios
```

Atau di `Package.swift`:

```swift
dependencies: [
    .package(
        url: "https://github.com/FvorY/pdf-signature-sdk-ios",
        branch: "main"
    )
]
```

Kemudian tambahkan product `PdfSignatureSDK` ke target aplikasi.

### CocoaPods

```ruby
pod 'PdfSignatureSDK', :git => 'https://github.com/FvorY/pdf-signature-sdk-ios.git'
```

Jalankan:

```bash
pod install
```

Buka file `.xcworkspace`, bukan `.xcodeproj`.

Versi saat ini masih preview (`0.0.0`) dan belum ada tag rilis, jadi gunakan branch `main`.

## UIKit

`PdfSignatureView` adalah subclass `UIView` dan dapat dipasang langsung di `UIViewController`.

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
                print("Gagal membuka PDF: \(error)")
            }
        }
    }
}
```

PDF juga dapat dimuat langsung saat membuat view:

```swift
let config = PsdkConfig(file: .file(pdfURL))
let viewer = PdfSignatureView(config: config)
```

Sumber yang tersedia:

```swift
.file(URL(fileURLWithPath: path))
.data(pdfData)
.bundle(name: "contoh.pdf")
.remote(URL(string: "https://example.com/document.pdf")!)
```

## Menempatkan tanda tangan dan E-Materai

```swift
let signatureID = try viewer.placeSignature(PlaceOptions(
    x: 80,
    y: 120,
    page: 1,
    label: "Direktur",
    width: 160,
    height: 48
))

let stampID = try viewer.placeEStamp(PlaceOptions(
    x: 300,
    y: 120,
    page: 1,
    label: "Materai 10.000",
    width: 80,
    height: 80,
    locked: true
))
```

Untuk membuka picker bawaan:

```swift
viewer.openSignatureModal()
viewer.openEStampModal()
```

Opsi `PlaceOptions` yang penting:

| Opsi | Kegunaan |
|---|---|
| `x`, `y` | Posisi kiri-atas dalam PDF point |
| `page` | Nomor halaman, dimulai dari 1 |
| `label` | Label item yang ditampilkan |
| `image` | Gambar tanda tangan atau E-Materai |
| `width`, `height` | Ukuran dalam PDF point |
| `disableDrag` / `disableDragging` | Mencegah item digeser |
| `disableResize` | Mencegah item di-resize |
| `locked` | Mengunci item |

## Mengambil hasil

```swift
let items = viewer.getSignatures()
let jsonData = try JSONEncoder().encode(items)
let json = String(data: jsonData, encoding: .utf8)
```

Contoh item:

```json
{
  "id": "signature-1760600000000-1",
  "type": "signature",
  "x": 80,
  "y": 120,
  "page": 1,
  "label": "Direktur",
  "width": 160,
  "height": 48,
  "disableDrag": false,
  "disableDragging": false,
  "disableResize": false,
  "locked": false
}
```

Koordinat menggunakan sistem berikut:

- satuan: PDF point, 1/72 inci;
- origin: pojok kiri-atas halaman;
- `x` dan `y`: posisi kiri-atas item;
- nomor halaman dimulai dari 1;
- ukuran A4 portrait umumnya `595 × 842` point.

`yFromBottom(pageHeight:)` mengubah `y` untuk library PDF yang memakai origin kiri-bawah.

## Event

```swift
viewer.on(.documentLoaded) { event in
    if case let .documentLoaded(totalPages) = event {
        print("Total halaman: \(totalPages)")
    }
}

viewer.on(.signaturePlaced) { event in
    if case let .signaturePlaced(item) = event {
        print("Signature ditempatkan: \(item.id)")
    }
}

viewer.on(.signatureMoved) { event in
    print("Posisi item berubah: \(event)")
}
```

Event yang tersedia: `documentLoaded`, `pageChanged`, `signaturePlaced`, `eStampPlaced`, `signatureMoved`, `signatureRemoved`, `signaturesCleared`, dan `passwordRequested`.

`on` dan `once` mengembalikan `PsdkSubscription`; berikan ke `off` untuk berhenti mendengarkan. Dengan Combine, gunakan `eventsPublisher`.

## Halaman, zoom, dan lifecycle

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

Zoom yang didukung 0,25 sampai 4,0. Panggil `destroy()` saat view tidak lagi digunakan.

## PDF password

Jika PDF terkunci, SDK mengirim event `passwordRequested`:

```swift
viewer.on(.passwordRequested) { event in
    guard case let .passwordRequested(request) = event else { return }

    let alert = UIAlertController(
        title: "Password PDF",
        message: request.isIncorrect ? "Password salah" : nil,
        preferredStyle: .alert
    )
    alert.addTextField { $0.isSecureTextEntry = true }
    alert.addAction(UIAlertAction(title: "Batal", style: .cancel) { _ in
        request.cancel()
    })
    alert.addAction(UIAlertAction(title: "Buka", style: .default) { _ in
        request.updatePassword(alert.textFields?.first?.text ?? "")
    })
    present(alert, animated: true)
}
```

## Konfigurasi

```swift
let config = PsdkConfig(
    file: .file(pdfURL),
    labels: .indonesian,
    disableResize: true,
    secureScreen: true
)
```

Ubah konfigurasi setelah view dibuat:

```swift
viewer.updateConfig { $0.disabled = true }
```

`secureScreen: true` menutupi isi viewer saat layar sedang direkam atau di-mirror
(`UIScreen.isCaptured`). iOS tidak menyediakan cara untuk memblokir screenshot biasa.

Opsi berikut sudah ada di `PsdkConfig` tetapi **belum diterapkan** oleh viewer iOS versi preview:
`theme`, `colors`, `typography`, `ui` (toolbar, thumbnail, haptic, dialog password bawaan),
`lockScrollWhenPaginationLocked`, `estampKeepAspectRatio`, `logLevel`, dan `onUpload`.
Karena itu, tangani event `passwordRequested` sendiri seperti contoh di atas.

URL PDF remote harus HTTPS secara default. HTTP hanya dapat diaktifkan secara eksplisit:

```swift
let config = PsdkConfig(allowInsecureHttp: true)
```

Gunakan opsi tersebut hanya untuk endpoint lama yang dipercaya.

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

`PdfSignatureController` mem-publish `currentPage`, `totalPages`, `currentScale`, dan `signatures`,
serta menyediakan `PdfSignatureView` di `controller.view`.

## Batasan

SDK mengatur tampilan dan posisi item. SDK tidak melakukan:

- tanda tangan digital atau pembubuhan sertifikat;
- validasi identitas penanda tangan;
- penyimpanan dokumen ke backend;
- finalisasi byte PDF setelah signing.

Validasi identitas, koordinat, integritas dokumen, dan proses kriptografis tetap menjadi tanggung jawab backend.

## Menjalankan test dari source

```bash
scripts/test.sh
```

Lisensi: MIT.
