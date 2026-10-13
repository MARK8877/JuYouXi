# 视频详情沉浸页 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将“免费观看”入口改为同款沉浸式短剧详情页，并实现上下滑动切集、九宫格选集弹窗、模糊底图和失焦暂停。

**Architecture:** 复用现有 `_VideoPage` 播放器组件，通过 `initialEpisode` 和 `onEpisodes` 注入详情页的当前集与弹窗行为。`ShortDramaDetailsPage` 仅负责详情页的垂直 `PageView`、当前分页索引和选集弹窗；播放会话仍由每个激活的 `_VideoPage` 管理。`VideoPlayOverlay` 订阅播放器状态，生命周期和覆盖层打开前统一暂停。

**Tech Stack:** Flutter/Dart, `PageView`, `showModalBottomSheet`, `video_player`, Flutter widget tests.

**Spec:** `docs/superpowers/specs/2026-09-23-video-details-design.md`

## Global Constraints

- 不修改后端播放协议和 API 数据结构。
- 不新增依赖；复用现有视频播放、评论、点赞、收藏组件。
- 保持预览模式不发起网络播放请求。
- 所有图标按钮保留语义标签，触控区不小于 44pt。
- 视频底图只模糊海报层，不模糊前景视频画面。
- `IndexedStack` 下视频 Tab 只有在可见时才加载视频分页；离开视频 Tab 时播放器子树被卸载。

---

### Task 1: 更新行为测试

**Files:**
- Modify: `前端/test/widget_test.dart`

**Interfaces:**
- Verifies `ShortDramaDetailsPage` is immersive and that its episode sheet is opened explicitly from the bottom CTA.

- [ ] **Step 1: Write the failing test**

修改现有 widget 测试：进入“短剧详情”后断言仍显示 `返回首页`、`免费观看`，而不是自动出现 `选集`；点击详情页底部 `免费观看` 后断言选集弹窗显示九宫格 episode 按钮和 `关闭选集` tooltip。

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart`

Expected: FAIL because the current details route opens the picker immediately and renders `DramaDetailsSheet` instead of the immersive player.

### Task 2: 复用播放器到详情分页

**Files:**
- Modify: `前端/lib/src/video_feed.dart`

**Interfaces:**
- `_VideoPage({Episode? initialEpisode, Future<void> Function()? onEpisodes})` selects the injected episode and invokes the injected bottom-sheet callback.
- `ShortDramaDetailsPage({Drama drama, List<Episode> episodes, int initialEpisodeNumber, VoidCallback onSearch, bool previewMode})` renders the vertical episode pager.

- [ ] **Step 1: Add the smallest failing interaction assertions**

保持 Task 1 的 assertions，并增加 `find.byType(PageView)` 和 `find.byTooltip('关闭选集')` after opening the sheet.

- [ ] **Step 2: Implement the minimum wiring**

Add `_VideoPage.initialEpisode` and `_VideoPage.onEpisodes`; use `initialEpisode ?? drama.firstEpisode ?? Episode(1)` and render `onEpisodes ?? _openDetails` in `_BottomControls`. Change the parent `_openDetails` to release/close its own player before pushing the new route and pass `onSearch`, `previewMode`, and captured episode options.

- [ ] **Step 3: Implement the details pager**

Replace the AppBar/details body with `ColoredBox(color: Colors.black)` + `SafeArea` + `PageView.builder(scrollDirection: Axis.vertical)`. Build each page with `_VideoPage(initialEpisode: availableEpisodes[index], onEpisodes: _openEpisodePicker, onExit: Navigator.pop)`. Update the current index in `onPageChanged` and open on `initialEpisodeNumber`.

- [ ] **Step 4: Run tests**

Run: `flutter test test/widget_test.dart`

Expected: PASS for immersive details navigation and existing like/comment/save interactions.

### Task 3: 九宫格选集弹窗与关闭按钮

**Files:**
- Modify: `前端/lib/src/video_feed.dart`

**Interfaces:**
- `_EpisodePicker` receives resolved episode options and returns an `Episode` only when a cell is tapped; close icon dismisses with `null`.

- [ ] **Step 1: Implement the grid**

Resolve service episodes, drama episodes, episodeCount-generated options, or a first-episode fallback. Render a three-column `GridView.builder` with selected styling, `Semantics(button: true, selected: ...)`, and a header `IconButton(tooltip: '关闭选集')`.

- [ ] **Step 2: Connect selection**

When the sheet returns an episode, animate the details `PageController` to that episode's index; when it returns `null`, keep the current page unchanged.

- [ ] **Step 3: Run tests**

Run: `flutter test`

Expected: PASS with no analyzer warnings.

### Task 4: 模糊底图与失焦暂停

**Files:**
- Modify: `前端/lib/src/video_feed.dart`
- Test: `前端/test/widget_test.dart`

**Interfaces:**
- `VideoPlayOverlay({ValueListenable<VideoPlayerValue> valueListenable, VoidCallback onPlay})` exposes a 64dp accessible play button only for initialized paused video.

- [ ] **Step 1: Write the failing test**

断言视频页包含 `ImageFiltered`；使用 `ValueNotifier<VideoPlayerValue>` 驱动 `VideoPlayOverlay`，断言暂停时显示 `播放视频`，点击后执行回调，切换为播放状态后按钮消失。

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart`

Expected: FAIL because the current canvas has no blur layer and no play overlay.

- [ ] **Step 3: Implement the minimum behavior**

在 `_VideoCanvas` 的海报层外包 `ImageFiltered(ImageFilter.blur(sigmaX: 18, sigmaY: 18))` 并用轻微放大避免边缘空白；`_VideoPageState` 监听 `WidgetsBindingObserver`，在应用失焦以及评论/选集/搜索覆盖层打开前暂停。将 `VideoPlayOverlay` 放在渐变遮罩上方，播放按钮调用 controller.play()。

- [ ] **Step 4: Run tests**

Run: `flutter test`

Expected: PASS with the overlay hidden while playing.

### Task 5: Tab 可见性与单击暂停

**Files:**
- Modify: `前端/lib/main.dart`, `前端/lib/src/video_feed.dart`
- Test: `前端/test/widget_test.dart`

**Interfaces:**
- `VideoFeedPage.active` controls whether the feed subtree exists and whether metadata loading starts.
- `VideoPlaybackSurface({ValueListenable<VideoPlayerValue>? valueListenable, VoidCallback onPlay, VoidCallback onPause, Widget child})` pauses on a single tap while playing and exposes the play overlay while paused.

- [ ] **Step 1: Write the failing test**

首页启动断言不存在视频占位/播放器；`VideoPlaybackSurface` 使用 playing 状态的 `ValueNotifier`，单击后断言执行暂停回调。

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart`

Expected: FAIL because the existing `IndexedStack` builds the active video page at launch and no tap surface exists.

- [ ] **Step 3: Implement the minimum behavior**

由 `AppShell` 将 `_selectedIndex == 1` 传给 `VideoFeedPage.active`；inactive 时返回黑色占位并卸载 `PageView`，active 时再加载数据。用 `VideoPlaybackSurface` 包裹视频画面，playing 状态单击调用 `controller.pause()`，paused 状态显示已有 `VideoPlayOverlay`。

- [ ] **Step 4: Run tests**

Run: `flutter test`

Expected: PASS with no video content on the default home tab.

### Task 7: Verification

**Files:**
- Verify: `前端/lib/src/video_feed.dart`, `前端/test/widget_test.dart`

- [ ] **Step 1: Format and analyze**

Run: `dart format lib/src/video_feed.dart test/widget_test.dart && dart analyze .`

Expected: `No issues found!`

- [ ] **Step 2: Build iOS debug**

Run: `flutter build ios --debug --no-codesign`

Expected: `Built build/ios/iphoneos/Runner.app`.

### Task 6: 首页卡片入口

**Files:**
- Modify: `前端/lib/main.dart`
- Test: `前端/test/widget_test.dart`

**Interfaces:**
- `HomePage._showDetails(BuildContext context, Drama drama)` pushes `ShortDramaDetailsPage` with `initialEpisodeNumber` set to the first episode number or `1`.

- [ ] **Step 1: Write the failing test**

预览首页提供一个短剧卡片；点击卡片后断言没有传统 `短剧详情` AppBar，存在第 1 集沉浸播放器和返回控件。

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart`

Expected: FAIL because preview 首页没有卡片且卡片当前打开的是 `DramaDetailsSheet`。

- [ ] **Step 3: Implement the minimum behavior**

为 HomePage preview 数据提供 3 集样例；将首页卡片的 `_showDetails` 从 `showModalBottomSheet(DramaDetailsSheet)` 改为 `Navigator.push(ShortDramaDetailsPage(..., initialEpisodeNumber: 1))`，保留 `onSearch` 与 `previewMode`。

- [ ] **Step 4: Run tests**

Run: `flutter test`

Expected: PASS and the live page uses the existing playback session to open episode 1.
