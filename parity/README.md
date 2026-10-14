# Parity fixtures

These files check that this SDK returns the same positions as the web SDK
`pdf-signature-esign-sdk` **1.1.2**.

| Folder | Contents | Added in |
|---|---|---|
| `pdfs/` | Test documents: A4, Letter, landscape, mixed sizes, `/Rotate` 90/180/270, CropBox offset, password, 500 pages | M2 |
| `scenarios.json` | Actions to run, e.g. `placeSignature({ page: 2, x: 100, y: 200 })` | M2 |
| `web/` | Page that runs the scenarios with the web SDK and writes `expected/*.json` | M2 |
| `expected/` | Web SDK output. Item `id` values are ignored when comparing | M2 |

Results must match within ±0.5 pt. The same fixtures are used by the Android SDK.
