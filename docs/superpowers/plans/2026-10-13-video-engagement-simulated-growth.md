# 播放页模拟互动热度增长实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use the TDD sequence below; do not write production code before observing the corresponding test fail.

**Goal:** 在视频首页和视频详情页展示由后台定时推进、并持久化到 MySQL 的点赞、评论热度、收藏和转发模拟计数。

**Architecture:** Go store 每 10 分钟按短剧播放量目标推进计数；MySQL 行锁与下次增长时间保证重复运行不重复推进。API 读取模拟计数，Flutter 仅在视频页活跃时刷新；真实评论数与模拟评论热度分开展示，不生成模拟评论内容。

**Tech Stack:** Go 标准库、现有 `database/sql` MySQL store、现有 Flutter/http 客户端；不增加依赖。

**Spec:** 用户在当前任务审核通过的 2026-10-13 模拟增长方案。

## 全局约束

- 每 10 分钟最多推进一次；目标比例：点赞 3%、评论热度 0.2%、收藏 1%、转发 0.1%。
- 每次推进约为剩余目标差值的 0.8%-1.2%，四项分别随机取增量；不超过目标值。
- 播放量优先解析 `views`，缺失时解析 `heat`；两者不可解析时按 1,000 次播放的低基线模拟。
- 统计标记 `simulated: true`；评论弹窗区分真实评论和模拟评论热度，禁止生成虚构评论行。
- 不添加新依赖、不截图、不停止或重启正在运行的服务；不清理或暂存现有未跟踪文件。

---

### Task 1：增长函数与内存存储

**Files:**
- Modify: `数据库/internal/store/store.go`
- Test: `数据库/internal/store/store_test.go`

**接口：**
- `Store.GetEngagementHeat(ctx, dramaID) (EngagementHeat, error)` 返回模拟计数。
- `Store.AdvanceEngagementGrowth(ctx, now) error` 扫描剧库并推进到目标值。
- 增长函数纯计算、周期确定性，内存与 MySQL 使用同一规则。

- [ ] 先写测试：播放量 `100000` 的短剧在首个周期产生正向模拟计数，且各计数不超过对应目标。
- [ ] 运行该测试，确认因接口/功能缺失而失败。
- [ ] 再写测试：同一短剧同一周期重复执行不重复增长；新周期只向目标靠近且不越界。
- [ ] 运行测试确认失败原因仍是功能缺失。
- [ ] 实现计数类型、播放量解析、随机增量与 `Memory` 存储。
- [ ] 运行 `go test ./internal/store`，确认通过。

### Task 2：MySQL 持久化与 API

**Files:**
- Modify: `数据库/schema.sql`
- Modify: `数据库/internal/store/store.go`
- Modify: `数据库/internal/api/server.go`
- Modify: `数据库/internal/api/server_test.go`
- Modify: `数据库/openapi.yaml`

- [ ] 先写 API 测试：创建短剧并推进一次后，`GET /api/ui/engagement?dramaId=...` 返回四项模拟计数和 `simulated: true`。
- [ ] 运行测试确认该路由当前失败。
- [ ] 增加 `drama_engagement_heat` 表，主键为 `drama_id`，记录四个模拟计数与 `next_growth_at`。
- [ ] 实现 MySQL 读取及事务行锁推进；未到 `next_growth_at` 不更新，提交成功后将其延后 10 分钟。
- [ ] 实现只读统计 API，并同步 OpenAPI 响应结构；未知剧目 404、缺少 ID 400。
- [ ] 运行 `go test ./internal/store ./internal/api`，确认通过。

### Task 3：后台周期任务

**Files:**
- Modify: `数据库/cmd/server/main.go`
- Test: `数据库/cmd/server/main_test.go`（仅当调度启动逻辑需要独立验证时）

- [ ] 在 MySQL 模式启动标准库 `time.Ticker`，每 10 分钟调用 `AdvanceEngagementGrowth`；内存/文档模式不宣称持久化。
- [ ] 记录周期失败日志但继续下一周期；不添加额外服务或依赖。
- [ ] 运行 `go test ./...`。

### Task 4：Flutter 读取、刷新与说明

**Files:**
- Modify: `前端/lib/src/models.dart`
- Modify: `前端/lib/src/library_api.dart`
- Modify: `前端/lib/src/video_feed.dart`
- Test: `前端/test/library_api_test.dart`

- [ ] 先写 API 客户端测试：解析模拟计数及 `simulated` 标记。
- [ ] 运行测试确认失败。
- [ ] 增加 `EngagementHeat` 模型和现有 HTTP 客户端 GET 方法。
- [ ] 视频页激活时立即读取并每分钟刷新模拟热度；切离、后台暂停或销毁时取消计时器。
- [ ] 右侧四项显示模拟计数；点赞/收藏按钮本地状态仅在当前状态上加减 1，不改动原有交互。
- [ ] 评论弹窗保留真实评论列表与真实条数，并用紧凑说明独立标出“模拟热度 N”；不写入模拟评论。
- [ ] 运行 `flutter test` 与 `dart analyze`。

### Task 5：最终验证

- [ ] 运行 `cd 数据库 && go test ./...`。
- [ ] 运行 `cd 前端 && flutter test` 和 `dart analyze`；若工具链因中文路径失败，改用支持的 Dart 命令并如实报告。
- [ ] 检查差异仅涉及上述文件；不启动、不停止、不重启服务，不执行线上/现存数据库迁移。
- [ ] 说明新增表将在服务下次启动时由现有 schema migration 创建；当前运行进程保持不动。
