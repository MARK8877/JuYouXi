# 播放器进度条常显与底部间距 Implementation Plan

**Goal:** 在视频首页与短剧详情共用播放器底部常显进度轨道；加载完成后启用拖动和进度预览，并保持清晰的控件间距。

**Architecture:** 两个页面都使用 `lib/src/video_feed.dart` 中的 `_VideoPage`、`_BottomControls` 与 `VideoProgressBar`，因此只调整这条共享路径。播放器未就绪时保留同高触控区并显示静态轨道；有有效时长后在同一区域渲染原有 Slider。底部触控区从 24dp 增至 48dp，动作行上方间距为 8dp；描述区底部 inset 经 widget 几何测试定为 `safeArea + 120dp`，在工具栏上方保留 8dp 避让。

**Tech Stack:** Flutter/Dart、`video_player` 已有 `VideoProgressBar`、Flutter widget tests。

**Approved layout:** 已确认的聊天线框；进度区横向缩进 16dp、高 48dp、轨道 2dp；动作行按钮目标至少 48dp，进度区与动作行间隔 8dp，倍速与全屏控件之间间隔 8dp；加载未就绪时轨道可见但不可拖动。

## Scope

- Modify `前端/lib/src/video_feed.dart`, `前端/lib/src/models.dart` and `前端/test/widget_test.dart`, plus this plan.
- Do not add dependencies, change playback APIs, alter player loading/retry behavior, or edit other pages.
- Keep the existing seeking callback and preview thumbnail behavior after the player reports a valid duration.

---

### Task 1: Add regression coverage

**Files:** `前端/test/widget_test.dart`

- [x] Add a test that pumps `VideoProgressBar` with no controller and with an uninitialized `VideoPlayerValue`; assert a visible placeholder rail in a 48dp area and no active Slider.
- [x] Extend the ready-player drag test to assert the same 48dp area still contains the draggable Slider and the current preview behavior.
- [x] Add a preview-mode integration test for the video feed and details route; assert the placeholder rail remains visible in both while no playable controller is available.
- [x] Assert the actions row starts 8dp after the progress touch area and the description ends 8dp before the bottom control panel.
- [x] Run the new targeted tests and confirm they fail because the current widget hides its progress area before initialization and uses the old 24dp height/layout.

### Task 2: Implement the approved shared layout

**Files:** `前端/lib/src/video_feed.dart`

- [x] Make `VideoProgressBar` retain a keyed, 48dp area whether its listenable is null, uninitialized, or ready.
- [x] In null/uninitialized/zero-duration states, draw a centered 2dp muted static rail and keep it non-interactive; render no Slider until duration is positive.
- [x] Once ready, keep the current position Slider, drag preview and seek callback inside the same 48dp area.
- [x] Set the progress-area horizontal inset to 16dp; retain 8dp before the action row; add an 8dp gap between the right-side speed and fullscreen controls.
- [x] Move the description overlay bottom inset to `safeArea + 120dp`, preserving an 8dp clearance above the taller controls.
- [x] Run the targeted tests and confirm the shared implementation works in both routes.

### Task 3: Verify

- [x] Run `dart format lib/src/video_feed.dart test/widget_test.dart`.
- [x] Run `flutter test --reporter expanded`.
- [x] Run `dart analyze .`.
- [x] Add the conditional AI attribution label using shared drama metadata detection; test AI category/type/tag variants and the 30% white style.
- [x] Confirm no playback API, dependencies, server state, or unrelated page behavior changed; do not take screenshots.
