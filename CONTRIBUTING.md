# Contributing

## Setup

```bash
brew install swiftlint xcodegen
git clone git@github.com:FvorY/pdf-signature-sdk-ios.git
cd pdf-signature-sdk-ios
```

Open `Package.swift` in Xcode to work on the library, or
`Example/PdfSignatureExample.xcodeproj` to run the demo app.

## Checks before opening a PR

```bash
swiftlint lint --strict
scripts/test.sh
pod lib lint --allow-warnings --platforms=ios
```

## Example project

`Example/PdfSignatureExample.xcodeproj` is generated. Edit `Example/project.yml`, then run
`xcodegen` inside `Example/` and commit both files.

## Resources

Inside the library, load bundled files through a single helper (added in M1) that checks
`Bundle.module` (Swift Package Manager) and the `PdfSignatureSDK.bundle` resource bundle
(CocoaPods). Do not use `Bundle.module` directly in feature code, because it does not exist
under CocoaPods.

## Commits and branches

- Branch from `main` (`feat/...`, `fix/...`) and open a pull request.
- Use [Conventional Commits](https://www.conventionalcommits.org/) (`feat:`, `fix:`, `docs:`, `test:`, `chore:`).
- Add a line to `CHANGELOG.md` under **Unreleased**.

## Releasing (maintainer)

1. Set the same version in `PdfSignatureSDK.podspec` (`s.version`) and
   `Sources/PdfSignatureSDK/PdfSignatureSDK.swift` (`version`). Move the
   **Unreleased** notes in `CHANGELOG.md` under the new version.
2. Commit, then tag without a `v` prefix and push the tag:
   ```bash
   git tag 1.0.0 && git push origin 1.0.0
   ```
   The **Release** workflow verifies the versions and creates the GitHub Release.
   Swift Package Manager sees the new version as soon as the tag exists.
3. CocoaPods (owner only):
   ```bash
   pod trunk register <email> '<name>'   # once per machine
   pod trunk push PdfSignatureSDK.podspec --allow-warnings
   ```

Never move or delete a published tag. Release a new patch version instead.
