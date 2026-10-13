# 视频互动栏与评论持久化实施计划

**目标：** 视频首页与短剧详情共用实心图标+数字互动栏，并将评论面板按参考图重做；每部短剧首次读取且评论为空时，仅生成并持久化10条初始评论，之后通过同一 API 读取和追加评论。

**已确认线框：** 右侧竖排点赞、评论、收藏、转发实心图标及数字；白色近全屏底部评论面板，顶部显示总数并有展开/关闭，正文滚动，底部输入栏固定。

**数据边界：** 当前服务没有互动计数或评论接口。评论走现有库 API + MySQL；初始评论只在首次 GET 且无评论时写入，不对运行中的数据库执行手工播种。点赞/收藏维持页面当前状态切换、数字反映本次页面交互；评论数取数据库实际值；服务暂无分享计数，显示 0，不伪造历史互动量。

## 文件范围

- 前端：`前端/lib/src/models.dart`、`前端/lib/src/library_api.dart`、`前端/lib/src/video_feed.dart`、`前端/test/widget_test.dart`、`前端/test/library_api_test.dart`
- 数据/API：`数据库/schema.sql`、`数据库/internal/store/store.go`、`数据库/internal/api/server.go`、`数据库/internal/api/server_test.go`、`数据库/openapi.yaml`
- 本计划文件

不改播放 API、短剧发现/抓取逻辑、账号系统或真实运行库数据；不增加依赖。

## 任务

### 1. API 与存储

- [x] 定义评论 JSON 模型、列表/新增 Store 操作和字段校验。
- [x] Memory Store 为缺少评论的短剧产生一次10条可重复读取的演示评论；MySQL Store 对空短剧写入10条，并用 `(drama_id, seed_index)` 唯一约束保证并发 GET 不重复。
- [x] 新增按短剧查询/新增评论 API：GET 返回列表与 total；POST 持久化访客提交的评论。
- [x] 更新 schema 与 OpenAPI，使服务启动时现有 migrate 自动建表。
- [x] 先补 Go handler/store 测试：10条首读、后续不重复、POST 后读取可见、无效/不存在剧集校验。

### 2. Flutter UI

- [x] 补 Dart API/模型测试，覆盖评论列表解析与提交请求。
- [x] `_VideoPage` 打开评论时通过 API 加载；提交成功后以服务端返回内容更新列表与计数。
- [x] 按确认线框重做 `_ActionRail` 和 `_CommentSheet`，保留语义标签、至少44dp点击目标和安全区。
- [x] 点赞/收藏数字只反映当前页面状态；评论数字取返回 total；分享暂无服务端指标时显示0。
- [x] 用 widget tests 覆盖两个共用页面入口、评论显示/发送/关闭、常显数量与颜色。

### 3. 验证

- [x] 运行 Go API/store 测试。
- [x] 运行 Flutter widget/API 测试与 `dart analyze .`。
- [x] 不启动/重启服务、不对 MySQL 执行写入、不截图。
