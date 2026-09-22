# Neocities page

An indie-web style homepage for CatGrab, made for [Neocities](https://neocities.org/). It is
separate from `site/`, which is the GitHub Pages site.

## Upload

Upload every file in this folder to the root of the Neocities site (dashboard → drag and drop):

| File | What it is |
| --- | --- |
| `index.html` | the page: HTML, CSS and JS in one file |
| `icon.png`, `favicon.png` | the app icon at 128 px and 64 px, made from `design/icon.png` |
| `settings.png`, `app-commands.png` | the screenshots from `docs/screenshots/` at half size |
| `catgrab-88x31.png` | the 88×31 button for other sites to link with |

Before uploading, put the site's absolute address into the `og:image` meta in `index.html`.

## Refresh the images

```bash
sips -Z 128 design/icon.png --out neocities/icon.png
sips -Z 64 design/icon.png --out neocities/favicon.png
sips -Z 1120 docs/screenshots/settings.png --out neocities/settings.png
sips -Z 1120 docs/screenshots/app-commands.png --out neocities/app-commands.png
```

The 88×31 button is pixel art drawn by a small Python script (no Pillow needed); the cat, the
text and the colours are in the script. It lives in `scripts/make-88x31-button.py`:

```bash
python3 scripts/make-88x31-button.py neocities/catgrab-88x31.png
```
