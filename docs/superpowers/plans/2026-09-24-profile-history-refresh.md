# 我的页面观看记录刷新实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用户打开“我的”页时重新读取观看记录，确保启动后新增的记录能显示。

**Architecture:** `AppShell` 将“我的”页是否当前激活传给 `ProfilePage`。个人页首次激活时加载数据，之后每次从非激活切到激活时刷新；播放上报接口和后端保持不变。

**Tech Stack:** Flutter Material 3, Dart, flutter_test, 现有 LibraryApi。

**Spec:** 本线程中用户确认的方案：进入“我的”页时刷新观看记录。

## Global Constraints

- 只改个人页的数据加载时机与对应 widget test。
- 复用 `LibraryApi.fetchPlaybackHistory()`；不改 API、数据库、播放器和其他页面。
- 不引入依赖，不执行数据库写入或服务器重启。

---

### Task 1: 个人页激活时刷新观看记录

**Files:**
- Modify: `前端/lib/main.dart`（AppShell/ProfilePage）
- Test: `前端/test/widget_test.dart`

**Interfaces:**
- Consumes: `LibraryApi.fetchViewer()`、`fetchPlaybackHistory()`、`fetchDramas()`。
- Produces: `ProfilePage.active` 状态；从 inactive 切换到 active 时重新加载现有数据。

- [x] **Step 1: Write a failing test** — 用可切换历史响应的 mock client，先让应用启动时历史为空，再提供一条观看记录并切换到“我的”，断言记录显示。
- [x] **Step 2: Run the test** — `flutter test test/widget_test.dart --plain-name 'refreshes playback history when the profile tab opens'`；测试按预期失败，页面状态未在 Tab 切换时刷新。
- [x] **Step 3: Implement the minimal change** — AppShell 传入 `active: _selectedIndex == 3`；ProfilePage 首次激活时加载，并在 `didUpdateWidget` 检测 false→true 时调用现有 `_load()`。
- [x] **Step 4: Verify** — 定向测试通过；全量 22 项 widget test 通过；`dart analyze .` 无问题。
