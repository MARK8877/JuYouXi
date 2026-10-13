# 视频评论密度、二级回复与互动栏 Implementation Plan

> **Inline execution:** 本计划在当前任务内逐步实施；每项先写可复现的失败测试，再写最小实现。当前仓库没有已提交历史，且前后端目录处于未跟踪状态，不创建或暂存提交。

**Goal:** 收紧视频评论面板的纵向留白，修正评论头部排列，新增持久化二级回复，缩小视频互动图标并将计数固定为白色；同时把个人页“我的消息”到“最近看过”的可见间距精确缩短15dp。

**Architecture:** 复用当前 `_CommentSheet`、`/api/ui/comments` 与 `drama_comments` 表。回复在同一表新增可空 `parent_id`，API 继续返回扁平列表，由 Flutter 按父评论分组；服务端只允许根评论作为父级，因此最多两层。评论计数包含根评论与回复，`replyCount` 为根评论实际回复数。

**Tech Stack:** Flutter/Dart、Go、MySQL、现有 HTTP 客户端、Flutter widget tests 与 Go tests；不新增依赖。

**Spec:** 本计划中的“已确认交互”段落，源自用户附图及本轮对默认交互方式的确认。

## Global Constraints

- 只修改视频播放器共享布局、评论现有模型/API/存储、个人页对应间距、schema/OpenAPI 和对应测试。
- 视频互动目标至少 48×48dp；评论面板按钮至少 44×44dp；相邻互动目标间距至少 8dp。
- 回复只能挂在根评论下；不创建第三层；首次读取时现有10条种子评论保持为根评论，不自动播种回复。
- schema 代码允许服务下次启动时补充 `parent_id`；本次不重启服务、不操作正在运行的数据库、不截图。
- 评论 GET `total` 包含根评论和回复；成功回复时返回根评论最新 `replyCount`。

## 已确认交互

- 白色评论面板顶部显示居中的“X 条评论”，展开与关闭按钮固定在右侧，不与标题重叠。
- 一级评论沿用头像、昵称、正文、时间、回复和点赞；收紧列表上下 padding 与分隔距离。
- 一级评论下显示“展开 N 条回复”；默认折叠，展开后缩进列出二级回复。点二级回复的“回复”仍加入同一根评论线程，并在内容开头提及目标作者。
- 回复成功后自动展开对应线程；评论输入栏仍固定在底部并尊重安全区。
- 视频首页和详情共享 `_VideoPage`：右侧图标由42dp缩至32dp，按钮触控高度至少48dp，项间留8dp，数字显式使用白色；互动栏底部距控制栏8dp（由 widget 几何测试校准为安全区 +120dp）。

## Files

- `前端/lib/src/models.dart`：评论 `parentId`、评论回复提交结果与轻量 `copyWith`。
- `前端/lib/src/library_api.dart`：POST 可选 `parentId`。
- `前端/lib/src/video_feed.dart`：评论层级/展开/定向回复、紧凑排版、无重叠头部、互动栏布局/颜色。
- `前端/lib/main.dart`：只调整个人页快捷操作卡与最近观看卡片之间的纵向留白。
- `前端/test/library_api_test.dart`：回复字段编解码与 POST 请求断言。
- `前端/test/widget_test.dart`：评论面板与视频首页/详情互动栏回归。
- `前端/test/widget_test.dart`：同文件覆盖个人页“我的消息”到“最近看过”的间距回归。
- `数据库/schema.sql`、`数据库/cmd/server/main.go`：新表列与对既有表的幂等列迁移。
- `数据库/internal/store/store.go`：内存/MySQL 根评论及二级回复持久化、层级校验、计数维护。
- `数据库/internal/api/server.go`、`数据库/openapi.yaml`：可选父评论 API 字段与响应文档。
- `数据库/internal/api/server_test.go`：根评论回复持久化、计数、非法层级测试。

---

### Task 1: 先为回复 API/存储写失败测试

**Files:** `数据库/internal/api/server_test.go`

- [x] 新增 `TestDramaCommentRepliesPersistAtOneNestedLevel`：首次 GET 得到10条根评论；POST 根评论后用其 id 提交 `parentId` 回复；GET 返回总数12、根评论 `replyCount` 为1、回复 `parentId` 指向根评论。
- [x] 同一测试再把二级回复 id 作为 `parentId` 提交，断言返回400且总数仍为12；再测试跨短剧父评论也被拒绝。
- [x] 运行 `go test ./internal/api -run TestDramaCommentRepliesPersistAtOneNestedLevel -count=1`，确认因缺少 `parentId` 行为而失败。

### Task 2: 实现最小 Go 持久化与 API 支持

**Files:** `数据库/internal/store/store.go`、`数据库/internal/api/server.go`、`数据库/schema.sql`、`数据库/cmd/server/main.go`、`数据库/openapi.yaml`

- [x] 在 `DramaComment` 增加 `ParentID string `json:"parentId,omitempty"``；在 `DramaCommentInput` 增加可选 `ParentID string`。
- [x] Memory Store 创建回复前验证父评论属于同一短剧且 `ParentID` 为空；创建后把回复追加到同一列表并递增根评论 `ReplyCount`。
- [x] MySQL 表创建定义增加 `parent_id VARCHAR(128) NULL`。在 `migrate` 创建/更新既有表后查询 `information_schema.columns`，仅当列缺失时执行 `ALTER TABLE drama_comments ADD COLUMN parent_id VARCHAR(128) NULL`，避免假定 MySQL 小版本支持 `IF NOT EXISTS`。
- [x] MySQL 创建回复时用事务锁定同短剧根评论，拒绝不存在、跨短剧或自身为回复的父记录；递增根评论 `reply_count`，插入携带 `parent_id` 的回复并提交。
- [x] GET 继续返回扁平 `data`，每项包含可空 `parentId`，`total` 使用全部行数。POST 接收可选 `parentId`；成功后返回 `data`、全量 `total` 和服务端读取的 `parentReplyCount`。
- [x] 更新 OpenAPI：POST 请求 `parentId` 可选；`DramaComment.parentId` 可空；POST 响应 `parentReplyCount` 可选。
- [x] 运行 `go test ./internal/api ./internal/store`，确认新增与原有评论测试通过。

### Task 3: 先为 Flutter 回复模型/API 写失败测试

**Files:** `前端/test/library_api_test.dart`

- [x] 确认 `DramaComment.fromJson` 能从二级回复响应解析 `parentId`。
- [x] 调用 `submitComment(..., parentId: 'root-1')`，断言 POST JSON 含 `parentId`，并解析 `parentReplyCount`。
- [x] 运行 `flutter test test/library_api_test.dart --plain-name 'reads and submits persistent drama comments'`，确认新增断言因缺少 `parentId` 参数而失败。

### Task 4: 实现 Flutter 数据接口

**Files:** `前端/lib/src/models.dart`、`前端/lib/src/library_api.dart`

- [x] 添加 `DramaComment.parentId` 与 `copyWith({int? replyCount})`；添加 `CommentSubmission.parentReplyCount` 的可选解析。
- [x] 将 `LibraryApi.submitComment` 扩展为可选命名参数 `parentId`，仅非空时写入 JSON。
- [x] 重跑 Task 3 的测试，确认通过。

### Task 5: 先为评论面板、互动栏和个人页间距写失败 widget tests

**Files:** `前端/test/widget_test.dart`

- [x] 断言头部标题与展开/关闭按钮边界不重叠，且按钮触控目标不小于44dp。
- [x] 断言一级评论行 padding/分隔间距采用紧凑尺寸；默认无回复时不显示线程链接，新增回复后按根评论线程显示缩进回复。
- [x] 在预览模式回复根评论并发送，断言回复显示在该根评论下、总数增加；再从二级评论点击回复，断言仍归属根评论而不生成第三层。
- [x] 对视频 feed 和详情分别断言互动图标尺寸为32dp、数字颜色为 `Colors.white`、按钮触控高度至少48dp且项间距8dp。
- [x] 断言个人页“最近看过”标题与“我的消息”文字间距比现状减少15dp，不缩小快捷操作触控区域。
- [x] 运行新增 widget tests，确认失败原因为当前头部/尺寸/层级行为不符。

### Task 6: 实现评论面板、视频互动栏与个人页间距

**Files:** `前端/lib/src/video_feed.dart`、`前端/lib/main.dart`

- [x] 将评论标题区改成不重叠的 Row 布局：两侧宽度平衡，标题居中，展开/关闭按钮固定右侧，各有44dp点击区。
- [x] 将每条根评论的垂直 padding 从8dp缩至4dp、分隔高度从14dp缩至8dp；保留列表顶部12dp/底部16dp滚动余量，正文/头像维持可读尺寸，不压缩触控目标。
- [x] 按 `parentId` 将 GET 扁平结果分组；只有 `replyCount > 0` 的根评论显示“展开 N 条回复”，默认折叠；展开后以内缩的轻量行显示二级评论。
- [x] “回复”把目标根评论 id 传给 API；二级评论回复时仍使用根 id，并预填 `@目标作者`；成功后更新服务端返回总数/回复数并展开线程。
- [x] 评论输入栏继续固定在面板底部；发送错误、预览模式和关闭行为保持现状。
- [x] 将互动 icon 设为32dp、文字显式白色；每个触控按钮至少48dp高、之间8dp；定位互动栏底边距为安全区加120dp，使其在底部控制面板上方8dp。
- [x] 仅压缩 `_ProfileQuickActions` 卡片底部空隙与其后的区块间距，使“我的消息”文字底部到“最近看过”标题顶部的距离减少15dp；保持快捷操作行和标题本身尺寸不变。
- [x] 运行 Task 5 新增测试，确认通过。

### Task 7: 全量验证与迁移边界确认

**Files:** 上述改动文件。

- [x] 运行 `gofmt -w internal/api/server.go internal/api/server_test.go internal/store/store.go cmd/server/main.go`（在 `数据库` 目录）。
- [x] 运行 `go test ./...`（在 `数据库` 目录）。
- [x] 运行 `dart format lib/main.dart lib/src/models.dart lib/src/library_api.dart lib/src/video_feed.dart test/library_api_test.dart test/widget_test.dart`（在 `前端` 目录）。
- [x] 运行 `flutter test --reporter expanded` 与 `dart analyze .`（在 `前端` 目录）。
- [x] 检查 OpenAPI 与 API JSON 字段一致；确认没有新增依赖、没有改动播放行为，没有重启服务、执行真实数据库写入或截图。
