# App Store hero image

Marketing hero used as the first screenshot on the Apple App Store listing
("Moongate: Klipper Control"). **App Store only** — not shown in the app or on
Google Play.

## Files

- `moongate-hero-6.5in-1284x2778.png` — the final hero at iPhone 6.5" size
  (1284×2778), which is the screenshot slot this listing uses. App Store ready.
- `hero.html` — the source layout (brand red on dark, headline + value prop +
  framed app screenshot). Designed on a 1320×2868 canvas.
- `shot.png` — the dashboard screenshot used inside the device frame
  (iPhone 14 Pro capture, 1179×2556).

## Re-rendering

Render the layout with headless Chrome, then resize to the 6.5" slot size:

```sh
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless=new --disable-gpu --hide-scrollbars \
  --force-device-scale-factor=1 --allow-file-access-from-files \
  --window-size=1320,2868 \
  --screenshot="hero-1320x2868.png" \
  "file://$PWD/hero.html"

sips --resampleHeightWidth 2778 1284 hero-1320x2868.png \
  --out moongate-hero-6.5in-1284x2778.png
```

Edit the headline/subtitle/screenshot in `hero.html` and re-run to regenerate.
The App Store Connect iPhone slot for this app accepts 1242×2688 or 1284×2778.
