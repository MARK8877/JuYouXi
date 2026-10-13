# 剧有戏视频页互动实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (or subagent-driven-development) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为现有短剧视频流加入集数选择、详情跳转、首集循环播放、点赞/收藏状态和本地评论面板。

**Architecture:** 保持 `VideoFeedPage` 与 `_VideoPage` 的现有结构；由页面状态持有当前集、点赞/收藏和本地评论，使用 `showModalBottomSheet` 展示集数与评论，使用 `Navigator.push` 进入轻量短剧详情页。播放器仍只为当前页创建，切换集数时释放旧控制器并初始化新集。

**Tech Stack:** Flutter Material、现有 `video_player`、现有 `LibraryApi`/`Drama`/`Episode` 模型；不增加状态管理和评论网络依赖。

**Spec:** 已确认线框（2026-09-23 对话，用户回复 `1`）。

## Global Constraints

- 只修改 `/Users/mark/Documents/ChatGPT/剧有戏/前端` 及本计划文件；不修改 `/数据库`。
- 复用现有视频播放器、API 和详情视觉；不伪造后端评论、点赞数或收藏数。
- 没有真实 episode URL 时保留不可用状态；集数列表仍可展示并标记当前集。
- 所有面板遵守安全区、滚动边界和至少 48dp 触控目标；不截图验证。
- 现有 9010 服务保持运行；不输入或持久化密码。

## File Map

- Modify `前端/lib/src/video_feed.dart`: 当前集状态、集数/详情/评论面板、点赞收藏交互、切集播放器重建。
- `前端/lib/main.dart`: 不修改；详情路由直接复用视频页所在模块，避免扩散 AppShell。
- Modify `前端/test/widget_test.dart`: 覆盖视频页按钮、集数面板、评论面板、状态切换和详情返回。
- Modify `前端/test/library_api_test.dart`: 覆盖多集解析与缺失播放地址仍保留集数。

## TDD Tasks

1. **Red tests**
   - [x] 扩展多集 Episode JSON 测试，验证顺序、当前集和缺失 URL。
   - [x] 扩展 widget smoke test，验证“免费观看”“评论”、集数选择、点赞/收藏状态和详情页标题。
   - [x] 运行 `flutter test`，确认新增断言失败。

2. **Minimal implementation**
   - [x] 在 `_VideoPage` 中维护 selected episode、liked、saved、comments 状态。
   - [x] 点击底部免费观看进入详情页并立即弹出集数面板；点击集数更新当前集并重新初始化播放器，默认第一集循环播放。
   - [x] 点赞/收藏切换图标和语义文字；评论打开白色圆角底部面板，支持本地提交一条评论。
   - [x] 复用现有 `DramaDetailsSheet` 风格创建详情页，不引入新依赖。

3. **Verification**
   - [x] `dart format lib test`
   - [x] `dart analyze .`
   - [x] `flutter test`
   - [x] `flutter build ios --debug --no-codesign`
   - [x] 检查 9010 listener 与 `/health`，确认没有凭据变更。

## Acceptance Criteria

- 视频页首次进入自动播放第 1 集并循环；切换集数后只播放新选集。
- 点击“免费观看”先 push 详情页，再从底部打开全部集数面板；当前集高亮。
- 点赞、收藏点击后有可见选中状态；评论面板符合参考图的信息层级并可提交本地评论。
- 详情页和弹窗均可返回/关闭，现有首页、追剧、我的和历史测试不回归。
