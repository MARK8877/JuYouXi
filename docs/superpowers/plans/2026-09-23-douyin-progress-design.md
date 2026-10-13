# Douyin-Style Video Progress Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the shared video feed/detail scrubber follow a Douyin-style bottom layout with a thumb-following preview while dragging.

**Architecture:** Keep `VideoProgressBar` as the single shared component used by `_VideoPage` in both the feed and detail routes. Replace the current reserved-height preview layout with an edge-aligned scrubber overlay so the bar stays at the bottom and the preview floats above the thumb without moving the episode controls. Do not change playback APIs, navigation, or episode selection.

**Tech Stack:** Flutter Material `Slider`, `video_player`, existing poster/cover URLs, widget tests.

**Spec:** Approved in chat on 2026-09-23; no external Douyin screenshot was supplied, so the implementation follows the standard iOS Douyin vertical-player interaction pattern rather than claiming pixel identity to an unspecified app version.

## Global Constraints

- Keep the existing top controls, video frame y=0 behavior, and bottom safe-area background.
- The progress track is a 2px line with a visible 10px thumb only while dragging, inset 24px from both screen edges.
- The preview is 112x64, follows the thumb, clamps to the available width, and shows the current time.
- Keep every interactive target at least 44pt; do not add a dependency.
- Hide the scrubber when the controller is absent, uninitialized, or has no duration.

### Task 1: Lock the interaction contract

**Files:**
- Modify: `前端/test/widget_test.dart`

- [x] **Step 1: Add a failing test** that asserts idle and dragging track states, the preview key, a forwarded seek, and preview cleanup after pointer-up.
- [x] **Step 2: Run `flutter test test/widget_test.dart --plain-name 'shows a draggable progress preview' -r expanded` and confirm it fails for the missing layout contract.

### Task 2: Implement the Douyin-style scrubber

**Files:**
- Modify: `前端/lib/src/video_feed.dart`

- [x] **Step 1: Keep the slider edge-aligned** inside the existing bottom controls without changing the episode row height.
- [x] **Step 2: Add idle/dragging visual tokens** for track height, thumb size, and active/inactive colors.
- [x] **Step 3: Position the preview above the thumb** with clamped horizontal placement and the existing poster/cover fallback.
- [x] **Step 4: Preserve deferred drag-end state cleanup** so pointer-up cannot call `setState` while Flutter is build-locked.
- [x] **Step 5: Run the targeted test and confirm it passes.**

### Task 3: Verify the shared feed/detail behavior

**Files:**
- None beyond the files above.

- [x] **Step 1: Run `dart analyze .`.**
- [x] **Step 2: Run `flutter test test/widget_test.dart -r expanded`.**
- [x] **Step 3: Run `flutter build ios --debug --no-codesign`.**
- [x] **Step 4: Confirm ports 9000 and 9010 remain listening.**
