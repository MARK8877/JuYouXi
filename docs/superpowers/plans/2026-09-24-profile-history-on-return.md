# 我的页观看历史可见时刷新 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 确保“我的”页从详情等子路由返回、重新可见时再次读取最新观看历史。

**Architecture:** 保留 `ProfilePage.active` 已有的底部标签切换刷新；在应用现有 Navigator 上复用 Flutter 内置 `RouteObserver`，由 `ProfilePage` 在上层路由 pop 后刷新历史。数据仍由既有 `LibraryApi.fetchPlaybackHistory()` 获取，不改 API。

**Tech Stack:** Flutter/Dart、内置 `RouteObserver` / `RouteAware`、`flutter_test`。

**Spec:** 当前对话中的用户要求：“我的页面最近看过功能需要每次展示页面的时候展示出观看历史数据”。

## Global Constraints

- 仅修改 `前端/lib/main.dart`、`前端/test/widget_test.dart` 和本计划文件。
- 保留现有底部标签切换刷新逻辑；刷新只在“我的”页 active 时执行。
- 不增加依赖，不修改观看历史 API、数据库或服务器。
- 不改变页面结构和滚动位置，不截图。

---

### Task 1: 复现详情页返回后观看历史未刷新的行为

**Files:**
- Modify: `前端/test/widget_test.dart`

**Interfaces:**
- Consumes: `JuyouxiApp`, `_ProfileHistoryClient`, `ProfilePage` 现有观看历史卡片。
- Produces: Widget test，先读到历史，再 push 临时详情路由，改变 API 返回值并 pop，验证重新可见时显示新结果。

- [x] 新增测试：用 `_ProfileHistoryClient(hasHistory: true)` 启动 App，切到“我的”，断言展示“观看记录测试剧”。
- [x] 从 root `Navigator` push 一个临时详情路由；将客户端改为 `hasHistory: false` 后 pop 回“我的”。
- [x] 断言“暂无播放历史”出现且旧记录消失。
- [x] 运行新测试并确认在当前代码上因路由 pop 未触发刷新而失败。

### Task 2: 监听 Profile 页面重新可见事件

**Files:**
- Modify: `前端/lib/main.dart`

**Interfaces:**
- Consumes: 现有 `ProfilePage.active` 生命周期、`_ProfilePageState._load()`。
- Produces: 应用级 `RouteObserver<PageRoute<dynamic>>`，以及在 `didPopNext` 且页面 active 时刷新观看历史的 `RouteAware`。

- [x] 将 RouteObserver 注册到 `JuyouxiApp` 的 `MaterialApp.navigatorObservers`。
- [x] 使 `_ProfilePageState` 订阅当前 `PageRoute`，路由变化时退订旧 route、在 `dispose` 中退订。
- [x] 在 `didPopNext` 中仅当 `widget.active && !widget.previewMode` 时调用现有 `_load()`。
- [x] 运行新增路由返回测试及现有“refreshes playback history when the profile tab opens”测试，确保两种重新可见路径均刷新。

### Task 3: 回归检查

**Files:**
- Modify: 无（除非本范围内的测试暴露问题）。

**Interfaces:**
- Consumes: Profile history 可见时刷新实现。
- Produces: 通过的 Widget test 与静态分析结果。

- [x] 运行 `flutter test test/widget_test.dart -r expanded`。
- [x] 运行 `dart analyze .`。
- [x] 确认后端/API 无变更。
