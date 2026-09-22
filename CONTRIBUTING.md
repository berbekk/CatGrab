# Contributing to CatGrab

Thanks for taking an interest. Bug reports, translation fixes and pull requests are all welcome.

## Getting set up

You need Xcode 26 or newer, or just its Command Line Tools (`xcode-select --install`): the glass
sectors use macOS 26 APIs, so the macOS 26 SDK is required to compile. The app itself still runs on
macOS 13+. To work in Xcode, open `Package.swift` — no project file needed.

```bash
git clone https://github.com/berbekk/CatGrab.git
cd CatGrab
swift test        # run the tests
make run          # build build/CatGrab.app and launch it
```

| Command | What it does |
| --- | --- |
| `make build` | Build `build/CatGrab.app` for this Mac |
| `make run` | Build and launch |
| `make install` | Build and copy to `/Applications` |
| `make test` | Unit tests |
| `make lint` | SwiftLint in `--strict` mode, like CI (`brew install swiftlint`) |
| `make dmg` | Universal `build/CatGrab.dmg`, the file users download |
| `make verify-release` | Mount the DMG and check it the way users receive it |
| `make site` | Preview the website from `site/` at http://localhost:8000 |
| `scripts/run-first-launch.sh` | Launch with the welcome tour shown again, on your own menus |
| `scripts/run-fresh-install.sh` | Launch as a new user: default menus in a temporary config folder, tour from page one |

### Keeping your permissions

macOS ties Accessibility and Input Monitoring to an app's code signature, and an ad-hoc signature
changes on every build — so by default you grant both again after each rebuild. Run this once to
create a stable local signing identity; `build.sh` picks it up automatically:

```bash
./scripts/create-dev-signing-identity.sh
```

## How the code is organised

```
Sources/CatGrab/        App target: entry point, Info.plist, entitlements, icon source
Sources/CatGrabLib/     All logic and UI, in a library so tests can import it
  App/                  Application delegate, menu bar item
  Models/               Configuration model, Codable, schema migration
  Services/             Hotkeys, trackpad, permissions, actions, localization, config storage
  Views/                SwiftUI: the ring itself and the settings window
Tests/CatGrabLibTests/  Unit tests
design/                 Vector artwork the icon and SwiftUI shapes come from
scripts/                Icon rendering, signing helpers, release checks
site/                   The website (one self-contained index.html), deployed to GitHub Pages
```

- **Models** are `Codable` and versioned. If you change the shape of `PieConfiguration` or
  `PieMenuItem`, bump `currentSchemaVersion`, extend `PieConfigurationMigrator`, and add a test that
  an old config still decodes. Unknown fields and enum cases must degrade safely rather than throw.
- **Views** take sizes, colours, fonts and spacing from `DS` in
  `Sources/CatGrabLib/Views/DesignSystem.swift`, and settings screens are built from its shared
  pieces (`SettingsRow`, `SettingsCard`, `DSPopUpPicker`, `DSFieldButtonStyle`…). Add a token or a
  component there rather than a literal in a view — that is what keeps the settings consistent.
- **Strings** shown to the user go through `LocalizationStore`: add an `L10nKey` case and fill in every
  language in `Sources/CatGrabLib/Services/Localization.swift`. If you do not speak a language, copy
  the English text and say so in the PR. Never hardcode user-visible text in a view.
- **The app icon** is rendered from `design/cat.svg` by `scripts/render-app-icon.swift`;
  `build.sh` turns `AppIcon.png` into `AppIcon.icns` on every build.

## Pull requests

- One concern per PR. A refactor and a behaviour change in the same diff are hard to review.
- `swift test` and `swiftlint lint --strict` must pass; CI runs both plus a universal app build.
- Add a test when you fix a bug in the model or hotkey layer. For UI changes, say how you checked
  them by hand and attach a screenshot.
- Comments explain *why*, not *what*, and sit above non-obvious geometry and platform workarounds.
- Add a line under `Unreleased` in [CHANGELOG.md](CHANGELOG.md) for anything a user would notice.

## Reporting a bug

Open an issue with your macOS version, your Mac's chip, the CatGrab version, and what you expected
versus what happened. If a hotkey does not fire, check first that Accessibility and Input Monitoring
are both on in System Settings → Privacy & Security — that is the cause most of the time.

Security issues go to [SECURITY.md](SECURITY.md), not to the public tracker.
