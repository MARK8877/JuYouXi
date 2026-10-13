# Native Launch Splash Implementation Plan

> **For agentic workers:** Implement this approved plan inline; keep the change within existing native launch screens.

**Goal:** Give 剧有戏 a distinctive short-drama launch screen and launcher icon on iOS and Android.

**Architecture:** Generate a transparent stage-aperture mark, compose the approved wordmark lockup into resolution-appropriate PNG assets, and wire those assets into the existing iOS launch image and Android legacy/system splash resources. Use the same mark in the iOS AppIcon set and Android density/adaptive launcher icons.

**Tech Stack:** Built-in image generation, macOS `sips`/Swift only, Flutter assets, iOS storyboard, Android XML resources. No new packages.

**Spec:** Approved in the current conversation on 2026-09-28: stage-aperture mark, centered “剧有戏” and “好戏正在上演”, project palette.

## Global Constraints

- Keep the existing palette: `#17181C`, `#C93B32`, `#D5A548`, `#F6F7F9`, `#686C73`.
- Change only native launch and launcher icon artwork/resources; leave app pages, APIs, and services alone.
- Keep the same colors and brand mark in light and dark system modes.
- Do not take screenshots.

---

### Task 1: Create launch artwork

**Files:**
- Create: `前端/assets/branding/launch-mark.png`
- Replace: `前端/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage.png`
- Replace: `前端/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@2x.png`
- Replace: `前端/ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage@3x.png`
- Create: `前端/android/app/src/main/res/drawable-xxhdpi/launch_image.png`
- Create: `前端/android/app/src/main/res/drawable/splash_icon.xml`
- Create: `前端/android/app/src/main/res/drawable-xxhdpi/splash_branding.png`

- [x] Generate a transparent, flat stage-aperture symbol with vermilion and one gold light slit; no letters or play triangle.
- [x] Compose the symbol with the exact Chinese title and tagline on the approved dark background; export iOS images at 168×252, 336×504, and 504×756 px.
- [x] Export Android legacy artwork at 504×756 px and a 600×240 px branding line (200×80 dp); keep the Android 12+ central mark as a vector drawable within its 192 dp safe circle.

### Task 2: Wire both native splash paths

**Files:**
- Modify: `前端/ios/Runner/Base.lproj/LaunchScreen.storyboard`
- Modify: `前端/android/app/src/main/res/drawable/launch_background.xml`
- Modify: `前端/android/app/src/main/res/drawable-v21/launch_background.xml`
- Create: `前端/android/app/src/main/res/values-v31/styles.xml`
- Create: `前端/android/app/src/main/res/values-night-v31/styles.xml`

- [x] Write and run a temporary stdlib resource check first; it failed because the approved splash assets and Android 12+ theme resources did not yet exist.
- [x] Set iOS and Android legacy backgrounds to `#17181C` and center the shared lockup.
- [x] Set Android 12+ splash background, centered mark, and 200×80 dp branding image with native theme attributes; keep the current first-frame dismissal behavior.
- [x] Run the same resource check again and confirm every XML/asset reference resolves.

### Task 3: Configure launcher icons

**Files:**
- Replace: every PNG referenced by `前端/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Replace: `前端/android/app/src/main/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png`
- Create: `前端/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`
- Create: `前端/android/app/src/main/res/drawable/ic_launcher_foreground.xml`
- Keep: `前端/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json` and Android's existing `@mipmap/ic_launcher` manifest reference

- [x] Write a temporary resource assertion that checks iOS icon slot dimensions and Android adaptive icon references; confirm it fails because Android's adaptive icon XML is missing.
- [x] Render one opaque 1024×1024 icon from the existing transparent stage mark on `#17181C`, keeping the glyph centered and within Android's 66×66 dp foreground safe zone on a 108×108 dp canvas.
- [x] Export all iOS slot sizes and Android density PNGs from that master; add Android adaptive foreground/background resources without new dependencies.
- [x] Run the same resource assertion again and inspect the generated 1024px icon to verify palette, legibility, and transparent-free background.
