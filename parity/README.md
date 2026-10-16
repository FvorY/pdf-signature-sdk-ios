# Parity fixtures

These files check that this SDK returns the same positions as the web SDK
`pdf-signature-esign-sdk` **1.1.2**. They are copies of the Android SDK's `parity/` folder, where
the web runner that produces `expected/*.json` lives.

The fixtures sit in `Tests/PdfSignatureSDKTests/Parity/` so the test target can bundle them, and
`ViewerTests.testWebParityScenarios` runs every scenario against them.

| File | Contents |
|---|---|
| `pdfs/sample.pdf` | A4, A4 landscape, US Letter and a `/Rotate 90` page |
| `pdfs/geometry.pdf` | `/Rotate` 0/90/180/270, a CropBox inside a larger MediaBox, CropBox + `/Rotate 90`, a MediaBox not at 0,0 |
| `pdfs/password-aes256.pdf` | `sample.pdf` encrypted with user password `test123` |
| `scenarios.json` | Actions to run, e.g. `placeSignature({ page: 2, x: 100, y: 200 })` |
| `expected/*.json` | Web SDK output: page sizes and items. Item `id` values are not compared |

Results must match within ±0.5 pt. When the Android fixtures change, copy them here again.
