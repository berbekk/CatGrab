# Security Policy

## Supported versions

The latest release gets security fixes. Older versions do not.

## Reporting a vulnerability

Please report privately rather than opening a public issue — use
[GitHub's private vulnerability reporting](https://github.com/berbekk/CatGrab/security/advisories/new).

Include what an attacker can do, the steps to reproduce it, and your macOS and CatGrab versions.
Expect an acknowledgement within a week.

## What CatGrab can reach

Worth knowing when judging impact:

- The app requests **Accessibility** and **Input Monitoring**. Both are powerful: they let it observe
  keystrokes globally and synthesize input. CatGrab uses them to catch its hotkeys, send the
  keystroke an item is configured with, run window commands, and read the menus of the app in front.
- It runs **unsandboxed** with the hardened runtime and no entitlement exceptions.
- Configuration lives in `~/Library/Application Support/CatGrab/config.json` with your normal file
  permissions. It holds the actions you configured, including text snippets — do not put secrets in
  a snippet. Choosing a snippet also puts its text on the general clipboard.
- The only network traffic is favicon lookups when you choose a website icon, described in the
  [README](README.md#privacy).

## Verifying a download

Releases are built from this repository by GitHub Actions — see
[`.github/workflows/release.yml`](.github/workflows/release.yml) and the run linked from each release.
They are not notarized by Apple, so macOS asks you to confirm the first launch; that is expected. Only
download CatGrab from this repository's Releases page, and if you prefer, build it yourself from
source with `make install`.
