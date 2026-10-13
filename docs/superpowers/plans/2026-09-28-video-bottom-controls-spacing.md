# 视频底部控件间距优化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 收紧视频发现页底部操作栏、进度条与搜索栏的视觉间距，同时保留可用的触控尺寸和现有交互。

**Architecture:** 发现页的集数/倍速/全屏行高度收至44dp、操作栏至进度区间距4dp、进度区至搜索栏间距0dp。复查发现48dp进度区仍让轨道上下各留24dp可见空白，因此仅发现页将 `VideoProgressBar` 的全宽拖动区收至36dp；详情页默认维持48dp。同步降低发现页描述/操作栏锚点12dp，继续保持与面板顶部8dp间距。

**Tech Stack:** Flutter/Dart、Flutter widget tests；不新增依赖。

**Spec:** 本任务已确认的聊天线框与竞品截图（图片仅作为视觉参考）。

## Global Constraints

- 只修改 `前端/lib/src/video_feed.dart`、`前端/test/widget_test.dart`、`前端/test/library_api_test.dart` 和本计划文件。
- 不改视频播放/拖动逻辑、详情页布局、TabBar、导航、API/数据库或服务状态。
- 发现页按钮最小触控高度为44dp；发现页进度条全宽拖动区为36dp，详情页默认48dp。
- 视频描述和右侧操作栏与底部控件面板维持8dp间距，不能因面板压缩产生额外空白。
- 不截图、不新增依赖。
- 当前工作区源码均为未跟踪文件；保留现状，不执行清理、重置或提交操作。

---

### Task 1: Pin down compact discovery-feed spacing with a widget test

**Files:**
- Modify: `前端/test/widget_test.dart`

**Interfaces:**
- Consumes: the real `JuyouxiApp.preview()` video-feed UI and stable keys for bottom actions, progress touch area, and search footer.
- Produces: a widget regression test asserting the compact discovery-feed layout while preserving visible controls.

- [x] **Step 1: Add the failing layout test.** Pump the preview app, open “视频”, and assert the feed action row is 44dp tall, the gap below it is 4dp, the gap from the progress touch area to the search footer is 0dp, and the existing “免费观看”, speed, fullscreen, search, dislike, and TabBar controls remain visible.
- [x] **Step 2: Run the focused test and verify RED.** From `前端/`, run `flutter test test/widget_test.dart --plain-name 'keeps discovery bottom controls compact'`; it failed on the current 56dp action row, not on setup or compilation.

### Task 2: Compact only the feed bottom controls

**Files:**
- Modify: `前端/lib/src/video_feed.dart`

**Interfaces:**
- Consumes: existing `_BottomControls.discoveryFeed`, `VideoProgressBar`, and feed action callbacks.
- Produces: a denser discovery footer; non-feed detail controls remain unchanged.

- [x] **Step 1: Reduce feed-only action hitbox height to 44dp.** Apply `MaterialTapTargetSize.shrinkWrap` and `minimumSize` conditionally to the feed episode, speed, and fullscreen controls; reduce only the feed text-button horizontal padding enough to keep the episode CTA on one line with ellipsis on narrow widths. Retain the existing button sizing, padding, and wrapping for details.
- [x] **Step 2: Tighten feed-only vertical gaps.** Change the gap between the action row and progress area from 8dp to 4dp and remove the 4dp gap between the progress area and search footer; reduce the feed overlay bottom inset by 20dp to preserve the existing 8dp description/action-rail clearance. Leave non-feed spacing unchanged.
- [x] **Step 3: Run the focused layout test and verify GREEN.** The focused Flutter test passes with all geometry and control-visibility assertions.

### Task 3: Verify scope and regressions

**Files:**
- No additional files.

- [x] **Step 1: Format** with `dart format lib/src/video_feed.dart test/widget_test.dart` from `前端/`; final `--output=none --set-exit-if-changed` check reports 0 changed files.
- [x] **Step 2: Run all tests** with `flutter test --reporter expanded` from `前端/`; all 52 tests pass.
- [x] **Step 3: Run static analysis** with `dart analyze .` from `前端/`; no issues found.
- [x] **Step 4: Review the changed areas and status.** Only the two Dart files and this plan were edited for this task. The repo has no commits and its baseline source is untracked, so no commit, reset, screenshot, service, or data operation was performed.

### Task 4: Remove the remaining scrubber whitespace

**Files:**
- Modify: `前端/test/widget_test.dart`
- Modify: `前端/lib/src/video_feed.dart`

**Interfaces:**
- Consumes: `_BottomControls.discoveryFeed`, `VideoProgressBar` and the existing horizontal seek gesture.
- Produces: an optional `compact` mode on `VideoProgressBar`; feed passes `compact: true` and gets a36dp drag area, while all other callers default to48dp.

- [x] **Step 1: Extend the real feed layout test.** In `keeps discovery bottom controls compact`, assert that the feed `video-progress-touch-area` is36dp high; keep the confirmed44dp action row, 4dp top gap, zero gap to search footer, and visible existing controls.
- [x] **Step 2: Run the focused test and verify RED.** Run `flutter test test/widget_test.dart --plain-name 'keeps discovery bottom controls compact'` from `前端/`; before implementation it failed because the feed progress area remained48dp.
- [x] **Step 3: Implement feed-only compact scrubber sizing.** Add optional `compact = false` to `VideoProgressBar`; use36dp for both loading and ready states when compact, preserve48dp otherwise, and pass `compact: true` only from the discovery footer. Reduce the feed overlay bottom inset by12dp to preserve the existing8dp clearance above the shorter panel.
- [x] **Step 4: Verify compact scrubbing and unchanged detail sizing.** Assert the loaded compact slider still supports drag preview/time display; assert normal/direct and detail progress areas remain48dp. Align only stale test import prefixes with the existing `pubspec.yaml` package name `juyouxi`; do not change package or dependency configuration. Run the focused widget tests.

### Task 5: Re-verify the corrected implementation

- [x] Format the changed Dart files; run the full Flutter suite (52 tests pass) and `dart analyze .` (no issues); inspect the changed source and test sections. Start the updated front end on iPhone 18 Pro simulator; do not screenshot or restart services.
