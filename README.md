<div align="center">

<img src="design/icon.png" width="128" alt="CatGrab icon">

# CatGrab

**A radial launcher for macOS.** Press a hotkey or tap the trackpad, flick the pointer, release —
your app, shortcut, window command or snippet fires. No trip to the Dock, no digging through menus.

[![CI](https://github.com/berbekk/CatGrab/actions/workflows/ci.yml/badge.svg)](https://github.com/berbekk/CatGrab/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/berbekk/CatGrab?sort=semver)](https://github.com/berbekk/CatGrab/releases/latest)
[![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue)](#requirements)
[![License: MIT](https://img.shields.io/badge/license-MIT-green)](LICENSE)

**[Download CatGrab.dmg](https://github.com/berbekk/CatGrab/releases/latest)** · [Website](https://berbekk.github.io/CatGrab/) · [Русский](README.ru.md) · [Changelog](CHANGELOG.md)

<br>

<img src="docs/screenshots/settings.png" width="820" alt="CatGrab settings: the menu list, the hotkey and trackpad gesture, and a live preview of the ring">

</div>

## Features

- **Radial menus on a hotkey or a trackpad tap.** Every menu gets its own key combination — including
  a bare <kbd>Fn</kbd>/<kbd>🌐</kbd> press — and can also open with a light tap of three, four or
  five fingers.
- **Six kinds of action per sector:** launch an app, open a link, send a keystroke to the app in
  front, run a macOS action (Mission Control, App Exposé, Quick Note, Screen Saver, Display Sleep,
  Lock Screen), or put a text snippet on the clipboard ready for <kbd>⌘</kbd><kbd>V</kbd>.
- **Active apps.** A built-in ring of everything that is running — a radial <kbd>⌘</kbd><kbd>Tab</kbd>
  that also switches to the app's Space and restores minimized windows.
- **App commands.** One hotkey opens the commands of the app you are in: move the window to a half of
  the screen, fill or center it, full screen, quit. Give any app its own set — anything from its menu
  bar — and the same hotkey shows Figma's commands in Figma and Xcode's in Xcode.
- **Always readable.** The sector under the pointer shows its name and what it will do — the site,
  the key combination, the first words of the snippet. Near a screen edge the ring stays fully on
  screen and pulls the pointer to its center, so the same flick works everywhere.
- **Quick select.** While a menu is open, press the digit or letter shown on a sector, or use the
  arrow keys, Tab and Return.
- **Icons from anywhere:** SF Symbols, emoji, website favicons, your own image or text.
- **Make it yours:** 24 colour themes to start from — palettes, gradients, single colours — then
  fine-tune the colours, intensity, glass and icons, or give any sector its own colour. Size,
  rotation and a cat in the middle whose eyes follow the pointer. Settings come in light or dark.
- **13 languages**, and backup/restore of your whole setup as one JSON file.

<p align="center">
  <img src="docs/screenshots/app-commands.png" width="820" alt="The App commands menu: window commands around the app's icon">
</p>

## Install

1. Download **[CatGrab.dmg](https://github.com/berbekk/CatGrab/releases/latest)**.
2. Open it and drag **CatGrab** into **Applications**.
3. Open **CatGrab** from Applications.

### First launch

CatGrab is free and open source, and it is not notarized by Apple (that needs a paid developer
account). So the first time you open it, macOS asks you to confirm — once:

- **macOS 15 Sequoia and newer:** macOS says it could not verify CatGrab. Click **Done**, open
  **System Settings → Privacy & Security**, scroll down to *“CatGrab” was blocked…* and click
  **Open Anyway**, then **Open**.
- **macOS 13 Ventura and 14 Sonoma:** in Applications, Control-click **CatGrab**, choose **Open**,
  then **Open** again.

<details>
<summary>Prefer Terminal? One command does the same.</summary>

```bash
xattr -dr com.apple.quarantine /Applications/CatGrab.app
```

This removes the “downloaded from the internet” mark from CatGrab only. After it, CatGrab opens like
any other app.
</details>

### Permissions

CatGrab then asks for two permissions. Click **Open System Settings** and turn **CatGrab** on in each:

| Permission | Why |
| --- | --- |
| **Accessibility** | send keystrokes, run window and system commands, read the menus of the app in front |
| **Input Monitoring** | catch global hotkeys, including <kbd>⌘</kbd><kbd>Tab</kbd> and a bare <kbd>Fn</kbd> |

Settings open from the cat in the menu bar, or by opening CatGrab from Applications again.

### Requirements

macOS 13 Ventura or newer, on Apple silicon or Intel.

## Updating

Download the new DMG, quit CatGrab (menu bar icon → Quit) and drag the new app over the old one.
Your menus and settings stay where they are.

If a hotkey stops working after an update, macOS no longer recognises the permission it gave the
previous version. In **System Settings → Privacy & Security**, open **Accessibility** and
**Input Monitoring**, select CatGrab, remove it with **−**, then open CatGrab again and allow it once
more.

## Troubleshooting

<details>
<summary><b>The hotkey does nothing</b></summary>

Check that CatGrab is on in both **Accessibility** and **Input Monitoring**
(System Settings → Privacy & Security). If it is on but still silent, remove it with **−** and let
CatGrab ask again — an entry left over from an older version looks enabled but no longer applies.
</details>

<details>
<summary><b>There is no cat in the menu bar</b></summary>

On macOS 26, allow it under **System Settings → Menu Bar → Allow in the Menu Bar**. On a MacBook
with a notch the icon can also be hidden behind the notch when the menu bar is full. CatGrab notices
both cases and shows a banner in Settings; open Settings by launching CatGrab from Applications.
</details>

<details>
<summary><b>macOS says CatGrab is damaged or can't be opened</b></summary>

That is the download mark, not a broken app. Run the Terminal command from
[First launch](#first-launch), then open CatGrab again.
</details>

<details>
<summary><b>Uninstall</b></summary>

Quit CatGrab, move it from Applications to the Bin, then remove its settings and permissions:

```bash
rm -rf ~/Library/Application\ Support/CatGrab ~/Library/Caches/CatGrab
defaults delete io.github.berbekk.CatGrab
tccutil reset All io.github.berbekk.CatGrab
```
</details>

Still stuck? [Open an issue](https://github.com/berbekk/CatGrab/issues/new/choose) with your macOS
version and what you tried.

## Privacy

Everything stays on your Mac, in `~/Library/Application Support/CatGrab/config.json`. No account, no
telemetry, no analytics — the app ships a [privacy manifest](Sources/CatGrab/PrivacyInfo.xcprivacy)
saying so.

The only network request: when you choose a **website favicon** as an icon, CatGrab fetches it from
Google's and DuckDuckGo's favicon services or from the site itself, and caches it. That request
contains the domain you typed. Nothing else leaves your machine.

## Build from source

You need Xcode 26 or newer, or just its Command Line Tools (`xcode-select --install`). The app you
build runs on macOS 13+.

```bash
git clone https://github.com/berbekk/CatGrab.git
cd CatGrab
make install   # builds and copies CatGrab.app to /Applications
```

`make build` builds into `build/` without installing, `make test` runs the tests. See
[CONTRIBUTING.md](CONTRIBUTING.md) for the project layout and how to keep permissions between
rebuilds, and [RELEASING.md](RELEASING.md) for publishing a release.

## Author

Made by **Kudriash Vasiliy** — [Telegram](https://t.me/berbekk) · [GitHub](https://github.com/berbekk).
Questions, ideas and bug reports are welcome in [issues](https://github.com/berbekk/CatGrab/issues/new/choose).

## License

[MIT](LICENSE)
