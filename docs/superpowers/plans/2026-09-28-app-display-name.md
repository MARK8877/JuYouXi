# 剧有戏应用名称 Implementation Plan

> **For agentic workers:** Implement this approved plan inline; keep the change limited to the app's user-visible name and valid Flutter package metadata.

**Goal:** Show “剧有戏” as the app name on Android and iOS.

**Architecture:** Set Android's launcher label and iOS's display/bundle names to the Chinese product name. Keep the Dart package identifier `juyouxi_frontend`, which matches existing `package:` imports and the package naming rules.

**Tech Stack:** Flutter `pubspec.yaml`, Android manifest, iOS property list, Python standard library for a temporary resource assertion. No new dependencies.

**Spec:** User request in the current conversation: “将项目名称改成‘剧有戏’”.

## Global Constraints

- User-visible app name must be exactly `剧有戏`.
- Preserve Android application ID, Android namespace, iOS bundle identifiers, and existing Dart imports.
- Do not change pages, APIs, data, or services.

---

### Task 1: Align app display names and package metadata

**Files:**
- Modify: `前端/pubspec.yaml`
- Modify: `前端/android/app/src/main/AndroidManifest.xml`
- Modify: `前端/ios/Runner/Info.plist`
- Test: temporary `/private/tmp/check_juyouxi_display_name.py`

- [x] Write a Python standard-library assertion for the expected package name, Android label, iOS display name, and iOS bundle name; run it and confirm it fails against the current values.
- [x] Set `pubspec.yaml` `name` to `juyouxi_frontend` so it matches existing Dart imports and the valid package-name format.
- [x] Set Android `android:label`, iOS `CFBundleDisplayName`, and iOS `CFBundleName` to the exact text `剧有戏`.
- [x] Run the same assertion and confirm the names and package import identifier agree.
