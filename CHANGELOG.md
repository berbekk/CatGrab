# Changelog

All notable changes to CatGrab are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-09-22

First public release.

### Added

- Radial menus opened by a global hotkey — any combination, including a bare `Fn`/🌐 press — or by a
  light tap of three, four or five fingers on the trackpad. Each menu has its own hotkey and gesture.
- Six action types per sector: launch an app, open a link, send a keystroke to the app in front, run
  a macOS action (Mission Control, App Exposé, Quick Note, Screen Saver, Display Sleep, Lock Screen),
  put a text snippet on the clipboard, or leave the sector empty.
- Active apps: a built-in ring of running apps as a radial `⌘Tab`. Choosing an app switches to the
  Space its window is on and restores minimized windows.
- App commands: a built-in menu with the commands of the app in front — window halves, fill, center,
  full screen and quit by default. Any app can get its own set built from its menu bar, edited on a
  live ring with its own rotation.
- Quick select by digit or letter while a menu is open.
- Icons from SF Symbols, emoji, website favicons, local images or custom text.
- Appearance controls: glass sectors, per-sector colours, size, rotation, icon distance, the paw
  decoration and a cat in the hub whose eyes follow the pointer.
- 13 interface languages.
- Backup and restore of the whole configuration as JSON, with migration of older files.
- Universal build for Apple silicon and Intel, distributed as a DMG.

[Unreleased]: https://github.com/berbekk/CatGrab/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/berbekk/CatGrab/releases/tag/v1.0.0
