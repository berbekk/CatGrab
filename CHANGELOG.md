# Changelog

All notable changes to CatGrab are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.1] - 2026-09-22

### Fixed

- Active apps: on a quick repeated ⌘Tab the icon and paw of a sector could glide in from another
  sector — a sector's identity is now its place in the ring, so changed contents appear in place.
- Active apps: the ring is centered for any number of apps — the first sector (the app you came
  from) always points straight up; a rotation you set is an offset from there.

## [1.2.0] - 2026-09-22

### Added

- A welcome tour on first launch: the real ring to play with, the hotkey to try or change, two pages
  where the cat's paw shows a sector moving and the ring turning before you try the gestures
  yourself, the two built-in menus, a starting palette, then the permissions — and a final page that
  says what to press. Reopen it any time from Settings → General → Welcome tour.
- A hint under the Glass switch explaining Regular versus Clear.
- The default hotkey of a new Main menu is ⇧1. It is easy to press and easy to change on the tour's
  second page; note that it takes over “!” until it is changed.
- Active apps: “Apps in the ring” limits the menu to the most recently used apps (6 by default;
  4 to 12 or all). The app you came from is always first, the rest stay alphabetical.

### Fixed

- After the relaunch that applies Input Monitoring nothing appeared, so it was unclear whether CatGrab
  was running at all. Settings now open right after that relaunch with a banner naming the hotkey.
- The cat in theme cards was invisible on dark cards; it now has a readable silhouette and, for your
  own themes, the theme's cat colour.

## [1.1.0] - 2026-09-22

The ring now tells you what it is about to do, works from the keyboard, and opens faster.

### Added

- **Name under the pointer.** The sector you point at is labelled with its name and, for a link,
  a key combination or a snippet, with what exactly will happen: the site, the keys, the first words
  of the text. Every menu has it (before, only App commands did); switch it off per menu under
  Parameters → Details → Pointer.
- **Keyboard in an open menu.** Arrows pick the sector in that direction, Tab and ⇧Tab go around the
  ring, Return or Space run the highlighted sector. Right-click cancels, like Esc.
- **Name field** in the sector inspector. Links, key combinations and snippets name themselves
  (the site's domain, the combination, the first words) until you type your own.
- **Duplicate** a menu from its page or by right-clicking it in the list, and duplicate a sector by
  right-clicking it in the preview. A copy gets no hotkey or gesture, so it never fights the original.
- A one-line reminder under the hotkey of how the ring is used: hold, move toward a sector, release.
- The editor warns when two menus share a hotkey and names the one that wins.
- An app that is not installed on this Mac shows dimmed in the ring and cannot be chosen; the
  inspector says why.

### Improved

- Near a screen edge the ring is kept fully on screen and the pointer moves to its center, so the
  same flick picks the same sector anywhere on the screen.
- The entrance animation is shorter and starts almost at full size: the ring is readable on its
  first frame. Reduce Motion still disables it.
- The snippet preview moved from a bubble under the menu bar icon into the label next to the ring,
  where you are already looking.
- The editor preview shows the same label as the real ring.
- The highlighted sector no longer grows or retints the glass; it reads by a colour layer, a stronger
  outline, a larger icon and the paw. Changing glass inside its container made the whole ring
  re-render and flicker dark on fast sweeps, and the glass lagged behind the outline.

### Fixed

- A link typed without `https://` (`github.com`, `localhost:3000`) now opens. Before, the favicon
  loaded and the sector looked configured, but choosing it silently did nothing.
- Links containing spaces open (the address is percent-encoded).

### Performance

- The ring's window and its SwiftUI tree are created once at launch, warmed up, and reused. Opening a
  menu no longer builds a full-screen window: on a 10-sector menu the work between the hotkey and the
  first frame dropped from 20–37 ms (and 100 ms for the first open after launch) to a few milliseconds.
- Icons of every configured app and every image sector are decoded ahead of time and cached. Image
  and favicon sectors used to be read from disk and decoded on every hover.
- Moving the mouse inside a sector no longer re-renders the ring; only a change of sector does.

### Removed

- The snippet preview bubble under the menu bar icon (replaced by the label next to the ring).

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
  full screen and quit by default. Any app can get its own set built from its menu bar. Command menus
  are edited like any other menu: a sector can also launch an app, open a link, send a keystroke, run
  a macOS action or paste a snippet, with its own colours and quick-select key, and the full
  appearance panel works with a shared look or one just for that app.
- Quick select by digit or letter while a menu is open.
- Icons from SF Symbols, emoji, website favicons, local images or custom text.
- Appearance controls: glass sectors, per-sector colours, size, rotation, icon distance, the paw
  decoration and a cat in the hub whose eyes follow the pointer, and the colour of both the cat
  and the paw.
- Themes: save a menu's whole style — colours, shape and details — as a theme and give it to any
  menu. Edits show up as unsaved theme changes that you can revert or save, and a saved theme
  updates every menu that uses it.
- 24 cat-named colour palettes (Toe Beans, Catnip, Fat Cat…) — palettes, gradients and single colours
  with their own intensity, glass and icon style, applied to the current theme. Give any sector its
  own colour from an 84-colour palette or the colour wheel. The selected sector glows in its colour.
- Light or dark appearance for the app's windows, or follow the system.
- 13 interface languages, every screen fully translated.
- About: version, developer and links in General settings, in the menu bar menu and in the standard
  About window.
- Backup and restore of the whole configuration as JSON, with migration of older files.
- Universal build for Apple silicon and Intel, distributed as a DMG.

[Unreleased]: https://github.com/berbekk/CatGrab/compare/v1.2.1...HEAD
[1.2.1]: https://github.com/berbekk/CatGrab/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/berbekk/CatGrab/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/berbekk/CatGrab/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/berbekk/CatGrab/releases/tag/v1.0.0
