# Video Progress Scrubber Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a draggable video progress bar with a poster preview above the thumb while seeking to both the video feed and immersive drama details page.

**Architecture:** Reuse the existing `_VideoPage` and `_BottomControls` shared by both routes. A single `VideoProgressBar` consumes the controller's `ValueListenable<VideoPlayerValue>`, seeks on slider changes, and shows the current drama poster during drag. No API or navigation changes.

**Tech Stack:** Flutter Material 3, `video_player`, existing `Episode.posterUrl`/drama cover fallback.

**Spec:** User request in the current task.

## Global Constraints

- Keep the existing bottom safe-area behavior and black background flush to the device bottom.
- Do not add packages or change playback/session APIs.
- Hide the scrubber when no initialized duration is available.
- Preserve existing controls and touch targets.

---

### Task 1: Progress interaction contract

**Files:**
- Modify: `前端/test/widget_test.dart`

- [x] **Step 1: Write the failing test** for an initialized controller, a visible `Slider`, `onChangeStart` showing a preview, `onChanged` forwarding a seek position, and `onChangeEnd` hiding the preview.
- [x] **Step 2: Run the targeted test** with `flutter test test/widget_test.dart --plain-name 'shows a draggable progress preview' -r expanded`; expect failure because `VideoProgressBar` is not implemented.

### Task 2: Shared scrubber implementation

**Files:**
- Modify: `前端/lib/src/video_feed.dart`

- [x] **Step 1: Add `VideoProgressBar`** with a Material `Slider`, clamped duration math, poster/cover preview above the thumb while dragging, and `controller.seekTo` on slider changes.
- [x] **Step 2: Pass the active controller and poster fallback from `_VideoPage` into `_BottomControls`.
- [x] **Step 3: Place the scrubber above the existing row inside the bottom black background container so the safe-area background remains flush to the device bottom.
- [x] **Step 4: Run the targeted test and confirm it passes.**

### Task 3: Verification

**Files:**
- None beyond the files above.

- [x] **Step 1: Run `dart analyze .`.
- [x] **Step 2: Run `flutter test`.
- [x] **Step 3: Run `flutter build ios --debug --no-codesign`.
- [x] **Step 4: Confirm ports 9000 and 9010 remain listening.**
