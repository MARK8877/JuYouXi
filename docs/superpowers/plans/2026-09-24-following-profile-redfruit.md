# 追剧与我的页面红果风格改造 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将现有 Flutter 追剧页和我的页改造成红果短剧风格的轻背景、红色强调、卡片化布局，并补齐现有数据接口可支持的页面交互。

**Architecture:** 复用现有 `AppShell`、`LibraryApi`、`FollowingEntry`、`Drama` 和视频详情页。追剧页读取追剧记录并用短剧列表补齐封面与详情跳转；我的页读取访客信息和追剧数量，通过回调切换到追剧 Tab。所有状态、加载、错误、空状态继续留在现有页面状态对象中，不新增依赖或后端接口。

**Tech Stack:** Flutter Material 3, Dart, `flutter_test`, 现有 HTTP API。

**Spec:** `docs/superpowers/plans/2026-09-24-following-profile-redfruit.md` 及已确认的追剧/我的页面线框。

## Global Constraints

- 只修改追剧页、我的页及其必要的 AppShell 回调，不改首页和视频播放逻辑。
- 复用现有 API：`GET /api/ui/following`、`GET /api/ui/dramas`、`GET /api/ui/viewer`。
- 不新增依赖，不新增数据库字段，不伪造观看历史、登录、积分等未提供的数据。
- 遵守 Flutter 安全区、Material 语义和至少 44pt 的可点击区域。
- 先测试失败，再写最小实现；每个阶段运行针对性测试和完整测试。

### Task 1: 追剧页筛选与卡片交互

**Files:**
- Modify: `前端/test/widget_test.dart`
- Modify: `前端/lib/main.dart:FollowingPage`

**Interfaces:**
- Consumes: `LibraryApi.fetchFollowing`, `LibraryApi.fetchDramas`, `FollowingEntry`, `Drama`。
- Produces: 追剧中/已完结/全部筛选、继续观看跳转、移除追剧、加载/错误/空状态。

- [x] **Step 1: Write the failing tests**

  覆盖筛选标签、追剧卡片、继续观看按钮和空状态；预览模式提供确定性数据。

- [x] **Step 2: Run targeted tests and verify they fail**

  Run: `flutter test test/widget_test.dart --plain-name 'renders the red fruit following page'`

  Expected: FAIL because the existing page has no filter labels or card actions.

- [x] **Step 3: Implement the minimal page state and layout**

  用现有接口加载追剧记录和短剧元数据，按 `completed` 过滤，复用 `ShortDramaDetailsPage` 完成播放跳转。

- [x] **Step 4: Run targeted tests and verify they pass**

  Run: `flutter test test/widget_test.dart --plain-name 'renders the red fruit following page'`

  Expected: PASS。

### Task 2: 我的页个人头部与入口交互

**Files:**
- Modify: `前端/test/widget_test.dart`
- Modify: `前端/lib/main.dart:AppShell/ProfilePage`

**Interfaces:**
- Consumes: `LibraryApi.fetchViewer`, `LibraryApi.fetchFollowing`。
- Produces: 访客头部、追剧数量、追剧清单入口、数据来源/游客模式信息、切换追剧 Tab 回调。

- [x] **Step 1: Write the failing tests**

  覆盖访客信息、追剧数量和点击“追剧清单”切换到追剧 Tab。

- [x] **Step 2: Run targeted tests and verify they fail**

  Run: `flutter test test/widget_test.dart --plain-name 'renders the red fruit profile page'`

  Expected: FAIL because the current page没有追剧清单入口和新头部结构。

- [x] **Step 3: Implement the minimal profile layout and callback**

  在 `AppShell` 传入 `onOpenFollowing`，我的页只展示已有接口提供的信息。

- [x] **Step 4: Run targeted tests and verify they pass**

  Run: `flutter test test/widget_test.dart --plain-name 'renders the red fruit profile page'`

  Expected: PASS。

### Task 3: Regression verification

**Files:**
- Modify: `前端/test/widget_test.dart` only if assertions need final wording alignment。

- [x] **Step 1: Run formatting**

  Run: `dart format lib/main.dart test/widget_test.dart`

- [x] **Step 2: Run all Flutter tests**

  Run: `flutter test test/widget_test.dart -r expanded`

- [x] **Step 3: Run static analysis**

  Run: `dart analyze .`

- [x] **Step 4: Build iOS debug without signing**

  Run: `flutter build ios --debug --no-codesign`
