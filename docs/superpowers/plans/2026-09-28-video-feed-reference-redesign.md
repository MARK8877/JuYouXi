# 视频流竞品布局 Implementation Plan

> **For agentic workers:** Execute inline in this confirmed workspace. Follow the test-first steps below; do not delegate or create a worktree because this checkout has no commits and the project files are untracked.

**Goal:** 将视频流页改成已确认的沉浸式竞品布局，同时保留应用 Tabbar、剧集/倍速/全屏操作和常显可拖进度条；拖动预览显示当前时间与总时长。

**Architecture:** 只在 `VideoFeedPage` 使用新的顶部频道栏与底部搜索/不喜欢区域，继续复用 `_VideoPage`、`_ActionRail`、`_DramaOverlay`、`_BottomControls` 和 `VideoProgressBar`。视频详情页维持现有布局；共享进度预览仅将拖动时间扩展为“当前 / 总时长”。

**Tech Stack:** Flutter/Dart、Flutter widget tests、当前已安装的 `video_player`；不新增依赖。

**Spec:** 2026-09-28 已确认的聊天线框（当前任务对话）；现有进度条约束见 `docs/superpowers/plans/2026-09-24-video-progress-always-visible.md`。

## Global Constraints

- 只修改 `前端/lib/src/video_feed.dart` 和 `前端/test/widget_test.dart`；本计划文件用于实现边界记录。
- 不改其他页面、导航状态、后端/API、播放器生命周期、既有操作语义或服务状态。
- 不新增作者、搜索推荐词、真实“不喜欢”反馈或互动计数等不存在的数据；搜索文案从当前短剧标题生成，不持久化不喜欢状态。
- 视频主体保持全屏可见；覆盖控件紧凑，并沿用黑色渐变/轻透明样式。
- 不截图，不运行可能导致服务重启或数据库写入的命令。

---

### Task 1: Add failing widget coverage

**Files:**
- Modify: `前端/test/widget_test.dart`

**Interfaces:**
- Consumes: exported `VideoFeedPage`, `VideoProgressBar`, `JuyouxiApp.preview()`.
- Produces: regression assertions for the feed header/footer and scrub preview time.

- [x] **Step 1: Add a feed-layout test.** Pump `JuyouxiApp.preview()`, select “视频”, then assert the selected “发现” header, search action, `搜剧 · 预览短剧` footer, “不喜欢” affordance, visible progress placeholder, and `NavigationBar`. Also assert that the existing episode, speed, and fullscreen controls remain available.
- [x] **Step 2: Add a drag-time test.** In a ready-player `VideoProgressBar` with a 100-second duration, hold and drag the slider 72dp to the right; assert the current preview reads `00:59 / 01:40` during the held drag, then release and assert the transient preview disappears.
- [x] **Step 3: Run focused tests and verify RED.** Both focused tests failed before the implementation for the missing feed layout and missing current/total timestamp format, not compilation errors.

### Task 2: Implement the confirmed video-feed layout

**Files:**
- Modify: `前端/lib/src/video_feed.dart`

**Interfaces:**
- Consumes: existing `_VideoPage` state/actions, `widget.onSearch`, `widget.onExit`, `widget.drama`, and current progress `Duration`.
- Produces: feed-only top channel overlay and bottom search/dislike row; `_ProgressPreview` displays current and total time while dragging.

- [x] **Step 1: Add the feed-only header.** Show the back action, compact menu affordance, four reference channel labels with “发现” selected, and search action only when `widget.onEpisodes == null`; keep the detail-page `_TopControls` unchanged.
- [x] **Step 2: Add the feed-only footer.** Show a compact search chip using the current drama title and call the existing `onSearch`; add the reference “不喜欢” affordance with an honest unsupported-feedback message, not a fabricated persisted state. Preserve the existing episode, speed, fullscreen, and progress controls and keep the app `NavigationBar` visible.
- [x] **Step 3: Fit the feed overlays.** Keep the existing four action buttons and AI attribution; adjust only the feed description/footer insets as needed so text, controls, and progress track do not overlap on a 375×844 logical-pixel test surface.
- [x] **Step 4: Show current and total time in scrub preview.** Pass the active video duration to `_ProgressPreview` and render `_formatVideoDuration(position) / _formatVideoDuration(duration)` in its visible lower time strip; leave the preview hidden when not scrubbing.
- [x] **Step 5: Run both focused tests and confirm GREEN.** Both focused tests pass after the implementation.

### Task 3: Verify regression safety

**Files:**
- No additional files.

- [x] **Step 1: Format** with `dart format lib/src/video_feed.dart test/widget_test.dart` from `前端/`.
- [x] **Step 2: Run the complete Flutter widget/API test suite** with `flutter test --reporter expanded` from `前端/`; all 51 tests pass.
- [x] **Step 3: Run static analysis** with `dart analyze .` from `前端/`; no issues found.
- [x] **Step 4: Inspect whitespace and the targeted changes.** `rg` found no trailing whitespace in the two edited Dart files or this plan; the implementation stayed within the video page and its widget tests, with no API, dependency, server, database, or unrelated page changes. No screenshots were taken.
