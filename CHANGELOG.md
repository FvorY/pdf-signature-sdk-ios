# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the
project uses [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Swift package skeleton (`PdfSignatureSDK`, iOS 14+), privacy manifest, unit test target.
- Preview `PdfSignatureView` UIKit API, SwiftUI controller/wrapper, PDF loading, pagination,
  zoom, password events, signature placement and interactive item overlay.
- Remote PDF hardening with HTTPS-by-default, redirect validation and bounded input sizes.
- Asynchronous signature/E-Materai image loading from URL, Base64 or `UIImage`, including automatic
  height adjustment and `signatureMoved` parity behavior.
- CocoaPods podspec.
- Example app generated with XcodeGen.
- GitHub Actions: SwiftLint, unit tests, Example build, `pod lib lint`, tag release.
