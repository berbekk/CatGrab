# Screenshots

`ring.png`, `settings.png`, `app-commands.png` and `welcome.png` are used by the READMEs and the
website. They are taken by the app itself, so glass and icons look exactly as users see them:

```bash
swift build
DEMO=docs/screenshots/demo     # the demo config.json lives next to the images
OUT=docs/screenshots
B=.build/debug/CatGrab
A=CATGRAB_SCREENSHOT_ACTIVATE=1
env CATGRAB_CONFIG_DIR=$DEMO CATGRAB_SCREENSHOT_DIR=$OUT CATGRAB_SCREENSHOT_TARGET=pie        CATGRAB_SCREENSHOT_SIZE=820x540      CATGRAB_SCREENSHOT_NAME=ring         $B
env CATGRAB_CONFIG_DIR=$DEMO CATGRAB_SCREENSHOT_DIR=$OUT CATGRAB_SCREENSHOT_TARGET=settings   CATGRAB_SCREENSHOT_MENU=main        CATGRAB_SCREENSHOT_NAME=settings     $A $B
env CATGRAB_CONFIG_DIR=$DEMO CATGRAB_SCREENSHOT_DIR=$OUT CATGRAB_SCREENSHOT_TARGET=settings   CATGRAB_SCREENSHOT_MENU=appCommands CATGRAB_SCREENSHOT_NAME=app-commands $A $B
env CATGRAB_CONFIG_DIR=$DEMO CATGRAB_SCREENSHOT_DIR=$OUT CATGRAB_SCREENSHOT_TARGET=onboarding                                     CATGRAB_SCREENSHOT_NAME=welcome      $A $B
```

Run them one at a time. The app opens the window, waits for it to render, captures it through the
window server at Retina scale and quits (see `ScreenshotMode`). In this mode it registers no
hotkeys and leaves ⌘Tab alone, so an installed CatGrab can keep running next to it.

- `CATGRAB_SCREENSHOT_ACTIVATE=1` makes the window active (coloured switches and window buttons).
  Without it the window appears without taking focus — handy while checking a layout.
- `pie` draws the real ring over its own backdrop window; `CATGRAB_SCREENSHOT_BACKDROP=<image>`
  replaces the painted backdrop, `CATGRAB_SCREENSHOT_HIGHLIGHT=<n>` picks the highlighted sector.
- Other pages: `CATGRAB_SCREENSHOT_PANE=general` (or `app:<bundle id>`),
  `CATGRAB_SCREENSHOT_PANEL=appearance` (or `item`), `CATGRAB_SCREENSHOT_PAGE=<n>` for a tour page,
  `CATGRAB_SCREENSHOT_SIZE=880x520` for a window size.

The demo config has two menus (Main and Work), command sets for Safari and Finder, English, dark
appearance. The app does not write to it unless you change something in the window.
