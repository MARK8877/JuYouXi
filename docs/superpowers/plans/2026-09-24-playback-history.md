# 观看记录持久化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 播放短剧时将当前剧集写入当前浏览器的观看记录，并由个人中心读取、排序和展示。

**Architecture:** 9010 剧库 API 新增 `/api/ui/history`，复用现有 viewer cookie 和已经存在的 `playback_history` 表。Flutter 播放器在视频成功开始播放后异步上报剧集与集数，个人中心读取历史接口并复用已有封面、详情跳转组件；9000 临时播放服务不改动。

**Tech Stack:** Go net/http、现有 Store 接口、MySQL、Flutter/Dart、flutter_test。

**Spec:** 用户请求“观看视频后保存观看记录，并返回给前端展示”。

## Global Constraints

- 只增加观看记录读写链路，不改临时播放服务、视频播放控制和既有追剧接口。
- 复用 `viewers`、`dramas`、`playback_history` 和现有 cookie，不新增依赖或认证体系。
- 播放记录写入失败不能阻断视频播放；前端只展示接口实际返回的记录。
- 写入参数校验：`dramaId` 必填，`episodeNumber` 为 1–10000，进度和时长不能为负数。

### Task 1: Store and API contract

**Files:**
- Modify: `数据库/internal/store/store.go`
- Modify: `数据库/internal/api/server.go`
- Modify: `数据库/internal/api/server_test.go`
- Modify: `数据库/internal/store/store_test.go`
- Modify: `数据库/openapi.yaml`
- Modify: `数据库/README.md`
- Modify: `数据库/数据库数据结构文档.md`

**Interfaces:**
- Produces `store.PlaybackHistory`, `store.PlaybackHistoryInput`, `ListPlaybackHistory`, `RecordPlaybackHistory`.
- Exposes `GET /api/ui/history` and `POST /api/ui/history`.

- [x] **Step 1: Write failing store/API tests**
- [x] **Step 2: Run Go tests and verify the missing history behavior fails**
- [x] **Step 3: Implement memory and MySQL persistence plus HTTP handlers**
- [x] **Step 4: Update OpenAPI and database docs**
- [x] **Step 5: Run Go tests and verify they pass**

### Task 2: Flutter client and playback reporting

**Files:**
- Modify: `前端/lib/src/models.dart`
- Modify: `前端/lib/src/library_api.dart`
- Modify: `前端/lib/src/video_feed.dart`
- Modify: `前端/test/library_api_test.dart`

**Interfaces:**
- Consumes `POST /api/ui/history` via `LibraryApi.recordPlaybackHistory`.
- Produces `PlaybackHistoryEntry` values via `LibraryApi.fetchPlaybackHistory`.

- [x] **Step 1: Write failing model/client assertions**
- [x] **Step 2: Run the targeted Dart tests and verify they fail**
- [x] **Step 3: Implement model decoding, API methods, and non-blocking playback report**
- [x] **Step 4: Run targeted Dart tests and verify they pass**

### Task 3: Personal center display

**Files:**
- Modify: `前端/lib/main.dart`
- Modify: `前端/test/widget_test.dart`

**Interfaces:**
- Consumes `PlaybackHistoryEntry` from `LibraryApi.fetchPlaybackHistory`.
- Produces sorted playback-history cards with episode labels and existing details navigation.

- [x] **Step 1: Write failing profile history assertion**
- [x] **Step 2: Run the targeted widget test and verify it fails**
- [x] **Step 3: Load playback history and map it to existing profile cards**
- [x] **Step 4: Run targeted and full Flutter tests**

### Task 4: Verification

- [x] **Step 1: Format Go and Dart sources**
- [x] **Step 2: Run Go tests**
- [x] **Step 3: Run Flutter widget and client tests**
- [x] **Step 4: Run `dart analyze .` and iOS debug build**
- [x] **Step 5: Verify ports 9000 and 9010 remain listening**
