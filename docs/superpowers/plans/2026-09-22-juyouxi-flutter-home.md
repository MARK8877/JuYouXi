# 剧有戏 Flutter 首页与整体框架 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `/Users/mark/Documents/ChatGPT/剧有戏/前端` 创建一个可运行的 Flutter 移动端首页与四标签应用框架，并接入现有剧库 API。

**Architecture:** 使用原生 Material 组件、一个轻量 API 客户端和少量数据模型；首页、搜索、追剧、我的共用海报卡片与详情底部面板。顶部品牌栏、票根筛选标签和三列海报网格是唯一的视觉重点，所有网络状态在页面内处理。

**Tech Stack:** Flutter/Dart、Material 3、`http`；不引入状态管理、路由或图标依赖。

**Spec:** 已确认的“剧场票根式内容首页”线框方案（2026-09-22 对话确认 `1`）。

## Global Constraints

- 所有 Flutter 文件必须位于 `/Users/mark/Documents/ChatGPT/剧有戏/前端`。
- 不修改 `/数据库`，不停止或替换 9000/9010 服务。
- API 默认地址为 `http://127.0.0.1:9010`，通过 `--dart-define=API_BASE_URL=...` 覆盖。
- 首版只使用已存在的 `/api/ui/viewer`、`/api/ui/dramas`、`/api/ui/search`、`/api/ui/following`、`/api/ui/image`。
- 不实现没有后端支撑的播放进度、继续观看、榜单和推荐假数据。
- 触控目标至少 48dp，遵守安全区、语义标签、错误重试和系统深浅主题。

### Task 1: Scaffold and API/model tests

**Files:**
- Create: `前端/pubspec.yaml` and generated Flutter platform files
- Create: `前端/test/library_api_test.dart`
- Create: `前端/test/widget_test.dart`

**Interfaces:**
- `Drama.fromJson(Map<String, dynamic>)`
- `FollowingEntry.fromJson(Map<String, dynamic>)`
- `ViewerInfo.fromJson(Map<String, dynamic>)`
- `LibraryApi` request methods used by the app shell

- [x] Scaffold a minimal Android/iOS Flutter app in `前端/` and add only `http`.
- [x] Write JSON model tests and one smoke test for the four-tab shell.
- [x] Run the focused tests once and keep the expected RED failure before adding the missing app code.

### Task 2: Minimal API client and models

**Files:**
- Create: `前端/lib/src/models.dart`
- Create: `前端/lib/src/library_api.dart`
- Modify: `前端/test/library_api_test.dart`

**Interfaces:**
- `LibraryApi.fetchDramas()` → `Future<List<Drama>>`
- `LibraryApi.search(String)` → `Future<List<Drama>>`
- `LibraryApi.fetchFollowing()` → `Future<List<FollowingEntry>>`
- `LibraryApi.setFollowing(String, {bool? saved, bool? completed})` → `Future<void>`
- `LibraryApi.fetchViewer()` → `Future<ViewerInfo>`
- `LibraryApi.coverUrl(Drama)` → `Uri?`

- [x] Implement only the fields required by the cards and details panel, including tolerant cover URL and episode-count parsing.
- [x] Preserve the server viewer cookie for the current app session.
- [x] Add bounded error messages and API/model parsing tests.
- [x] Run API/model tests until green.

### Task 3: App shell and reusable drama UI

**Files:**
- Create: `前端/lib/main.dart`
- Create: `前端/lib/src/drama_widgets.dart`
- Modify: `前端/test/widget_test.dart`

**Interfaces:**
- `DramaCard`
- `DramaDetailsSheet`
- `JuyouxiApp`

- [x] Add semantic theme tokens for ink, stage white, vermilion, ticket gold and muted text.
- [x] Implement safe-area-aware four-item `NavigationBar`: 首页、搜索、追剧、我的.
- [x] Implement the three-column adaptive grid (five columns on wide screens), 3:4 cover ratio, two-line title clamp, and visible loading/error/empty states.
- [x] Use Material icons with labels and pressed feedback; no emoji icons or custom dependencies.
- [x] Implement the detail bottom sheet with description, episode metadata and follow/unfollow action.
- [x] Run widget tests and verify the shell renders with a fake empty API state.

### Task 4: Connect screens to real API

**Files:**
- Modify: `前端/lib/main.dart`
- Modify: `前端/lib/src/drama_widgets.dart`
- Modify: `前端/test/widget_test.dart`

- [x] Load `/api/ui/dramas` on 首页 and filter categories locally.
- [x] Load `/api/ui/search` from the labeled search field with a submit action.
- [x] Load and mutate `/api/ui/following` in 追剧, including retry and empty guidance.
- [x] Load `/api/ui/viewer` in 我的 and show anonymous/source status without inventing account data.
- [x] Keep the bottom navigation stable and preserve each tab's scroll state with `IndexedStack`.
- [x] Run the full Flutter test suite.

### Task 5: Verification

**Files:**
- Modify only generated metadata if Flutter tooling requires it.

- [x] Run `dart format` on `lib` and `test`.
- [x] Run `dart analyze .` and `flutter test`; `flutter analyze` itself is blocked by a reproducible LSP JSON error on this Chinese workspace path.
- [x] Attempt the Android debug build; it is blocked because no Android SDK is configured on this machine. The iOS debug build with `--no-codesign` succeeds after setting the generated deployment target to iOS 15.0 for Xcode 27.
- [x] Re-check that the server listeners remain unchanged and that no credentials were added to source files.
