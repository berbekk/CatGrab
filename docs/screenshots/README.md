# Screenshots

`settings.png`, `app-commands.png` and `welcome.png` are used by the READMEs and the website.
They are taken by the app itself, so glass and icons look exactly as users see them:

```bash
make build
DEMO=/tmp/catgrab-demo   # a folder with a demo config.json, see below
OUT=docs/screenshots
B=build/CatGrab.app/Contents/MacOS/CatGrab
CATGRAB_CONFIG_DIR=$DEMO CATGRAB_SCREENSHOT_DIR=$OUT CATGRAB_SCREENSHOT_TARGET=settings   CATGRAB_SCREENSHOT_MENU=main        CATGRAB_SCREENSHOT_NAME=settings     $B
CATGRAB_CONFIG_DIR=$DEMO CATGRAB_SCREENSHOT_DIR=$OUT CATGRAB_SCREENSHOT_TARGET=settings   CATGRAB_SCREENSHOT_MENU=appCommands CATGRAB_SCREENSHOT_NAME=app-commands $B
CATGRAB_CONFIG_DIR=$DEMO CATGRAB_SCREENSHOT_DIR=$OUT CATGRAB_SCREENSHOT_TARGET=onboarding                                     CATGRAB_SCREENSHOT_NAME=welcome      $B
```

The app opens the window, waits for it to render, captures it through the window server at Retina
scale and quits (see `ScreenshotMode`). The demo config used for the current images has two menus
(Main and Work), command sets for Safari and Finder, English, dark appearance.
