# Publishing a release

Pushing a tag named `vX.Y.Z` makes GitHub Actions build a universal (Apple silicon + Intel)
`CatGrab.dmg`, check it, and attach it to a GitHub Release with install instructions. Nothing else
is required — signing is optional and switches on by itself once its secrets exist.

## Cutting a release

1. Move the `Unreleased` entries in [CHANGELOG.md](CHANGELOG.md) under a new version heading with
   today's date, and update the compare links at the bottom.
2. Set `CFBundleShortVersionString` in [`Sources/CatGrab/Info.plist`](Sources/CatGrab/Info.plist) to
   the same version, so local builds show it too. The release build takes its version from the tag,
   so the DMG always matches the tag.
3. Commit, tag and push:

   ```bash
   git commit -am "Release 1.1.0"
   git tag v1.1.0
   git push origin main v1.1.0
   ```

4. Watch **Actions → Release**. When it is green, the release page has `CatGrab.dmg`, the notes from
   [`.github/release-notes.md`](.github/release-notes.md), and a list of merged changes.

To try the packaging locally first:

```bash
make dmg             # universal build/CatGrab.dmg
make verify-release  # mounts it and checks layout, version, architectures and signature
```

## The website

`site/index.html` is published to <https://berbekk.github.io/CatGrab/> by
[`.github/workflows/pages.yml`](.github/workflows/pages.yml) on every push that touches it. Turn it on
once: **Settings → Pages → Build and deployment → Source: GitHub Actions**. Preview locally with
`make site`.

## Signing (optional)

The workflow picks the best of three levels based on which repository secrets exist
(**Settings → Secrets and variables → Actions**):

| Level | Secrets | What users get |
| --- | --- | --- |
| Ad-hoc (default) | none | macOS asks to confirm the first launch. After every update the permissions must be granted again, because each build looks like a new app to macOS. |
| Stable certificate — **free, recommended** | `SIGNING_CERTIFICATE_P12_BASE64`, `SIGNING_CERTIFICATE_PASSWORD`, `SIGNING_IDENTITY` | The first launch still needs a confirmation, but permissions survive updates. |
| Developer ID + notarization | the three above with a Developer ID certificate, plus `APPLE_ID`, `APPLE_TEAM_ID`, `APPLE_APP_PASSWORD` | Opens without any warning. Needs the paid Apple Developer Program. |

### Stable certificate, without an Apple account

Run once on your Mac:

```bash
./scripts/create-release-signing-certificate.sh
```

It creates a self-signed certificate in `~/CatGrab-release-signing`, copies it to the clipboard as
base64 and prints the three secrets to add. Back that folder up and keep it private: a new
certificate means a new identity, and every user would have to grant permissions again once.

The README's instructions for the first launch stay correct at this level. If you later move to
Developer ID, remove the “First launch” section from both READMEs and from
`.github/release-notes.md`.

### Developer ID and notarization

1. Enrol in the [Apple Developer Program](https://developer.apple.com/programs/).
2. Create a **Developer ID Application** certificate, export it from Keychain Access as `.p12`, and
   add it as `SIGNING_CERTIFICATE_P12_BASE64` (`base64 -i cert.p12 | pbcopy`) with its password.
3. Set `SIGNING_IDENTITY` to the certificate's full name, e.g.
   `Developer ID Application: Your Name (TEAMID)`.
4. Add `APPLE_ID`, `APPLE_TEAM_ID`, and an app-specific password from
   [appleid.apple.com](https://appleid.apple.com) as `APPLE_APP_PASSWORD`.

The next tag is signed, notarized and stapled, and the check also runs Gatekeeper's assessment.
