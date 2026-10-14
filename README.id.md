# PdfSignatureSDK untuk iOS

PDF viewer native iOS (Swift). Dengan SDK ini, user bisa menaruh, menggeser, me-resize, dan
menghapus kotak **tanda tangan** dan **E-Materai** di dokumen. Posisi dikembalikan dalam
**PDF point**, sama persis dengan web SDK
[`pdf-signature-esign-sdk`](https://www.npmjs.com/package/pdf-signature-esign-sdk) v1.1.2,
sehingga backend yang sama bisa langsung menyelesaikan proses tanda tangan.

> 🚧 **Masih dalam pengerjaan.** Saat ini baru kerangka package (milestone M0). API viewer
> menyusul di milestone berikutnya dan belum bisa dipakai.

English: [README.md](README.md)

## Instalasi

**Swift Package Manager.** Di Xcode buka File → Add Package Dependencies…, tempel
`https://github.com/FvorY/pdf-signature-sdk-ios`, lalu pilih *Up to Next Major Version*.

**CocoaPods:** `pod 'PdfSignatureSDK'`

## Sistem koordinat

- Satuan: PDF point (1/72 inci). Kertas A4 = 595 × 842 pt.
- Titik nol: pojok **kiri-atas** halaman. Sumbu Y mengarah ke bawah.
- `x, y` adalah pojok kiri-atas item.

## Menjalankan test

```bash
scripts/test.sh
```

## Lisensi

[MIT](LICENSE)
