# 我的页面参考图改造 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将我的页面改造成参考图中的深色个人头部、快捷操作、横向历史卡片和功能菜单，同时保持现有追剧数据和导航交互可用。

**Architecture:** 继续复用现有 `ProfilePage`、`AppShell`、`LibraryApi`、`ViewerInfo`、`FollowingEntry` 和 `Drama`。个人头部使用系统安全区背景和 Material 图标；播放历史使用已有追剧记录与短剧封面作为最近观看数据源；未被现有 API 支持的消息、点赞、评论、VIP 等入口统一显示明确的未开放提示。

**Tech Stack:** Flutter Material 3, Dart, `flutter_test`, 现有 HTTP API。

**Spec:** 用户提供的参考图片与本计划中的已确认线框。

## Global Constraints

- 只改我的页面及 `AppShell` 为其传递搜索/追剧回调，不改首页和视频播放器行为。
- 复用已有 `/api/ui/viewer`、`/api/ui/following`、`/api/ui/dramas`，不修改后端接口和数据库。
- 不写死消息、点赞、评论、VIP 数字；接口未提供的功能必须显示清晰反馈。
- 顶部状态栏与个人头部使用同一深色背景，内容遵守安全区和 44pt 触控区域。
- 使用现有 Material 图标，不新增依赖。

### Task 1: 参考图个人中心视觉结构

**Files:**
- Modify: `前端/test/widget_test.dart`
- Modify: `前端/lib/main.dart:ProfilePage`

**Interfaces:**
- Consumes: `ViewerInfo`、`FollowingEntry`、`Drama`。
- Produces: 深色个人头部、快捷操作卡、播放历史横向卡、功能菜单、状态栏背景。

- [x] **Step 1: Write the failing tests**

  覆盖个人头部、快捷操作、播放历史、菜单和状态栏背景。

- [x] **Step 2: Run the targeted test and verify it fails**

  Run: `flutter test test/widget_test.dart --plain-name 'renders the reference profile page'`

  Expected: FAIL because the current profile page没有参考图结构。

- [x] **Step 3: Implement the minimal visual structure**

  增加安全区背景、头部渐变、快捷操作行、水平历史卡和菜单列表，所有文字/图标使用可访问语义。

- [x] **Step 4: Run the targeted test and verify it passes**

  Run: `flutter test test/widget_test.dart --plain-name 'renders the reference profile page'`

  Expected: PASS。

### Task 2: 参考图交互与数据映射

**Files:**
- Modify: `前端/test/widget_test.dart`
- Modify: `前端/lib/main.dart:AppShell/ProfilePage`

**Interfaces:**
- Consumes: `LibraryApi.fetchViewer`, `LibraryApi.fetchFollowing`, `LibraryApi.fetchDramas`。
- Produces: 追剧统计跳转、历史卡进入详情、设置/快捷入口反馈、加载/错误状态。

- [x] **Step 1: Write the failing interaction assertions**

  覆盖追剧统计切换 Tab、历史卡进入详情和未开放入口提示。

- [x] **Step 2: Run the targeted test and verify it fails**

  Run: `flutter test test/widget_test.dart --plain-name 'handles reference profile interactions'`

  Expected: FAIL because the current profile page没有这些交互。

- [x] **Step 3: Implement the minimal callbacks and data loading**

  复用现有 `onOpenFollowing`，新增搜索回调用于历史卡详情页，历史卡以追剧记录的已知集数打开。

- [x] **Step 4: Run the targeted test and verify it passes**

  Run: `flutter test test/widget_test.dart --plain-name 'handles reference profile interactions'`

  Expected: PASS。

### Task 3: Regression verification

- [x] **Step 1: Format**

  Run: `dart format lib/main.dart test/widget_test.dart`

- [x] **Step 2: Run all Flutter tests**

  Run: `flutter test test/widget_test.dart -r expanded`

- [x] **Step 3: Run static analysis**

  Run: `dart analyze .`

- [x] **Step 4: Build iOS Debug**

  Run: `flutter build ios --debug --no-codesign`
