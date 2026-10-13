# 剧有戏 Flutter 视频 Tab 实现计划

> 目标：把底部 Tabbar 的“搜索”入口替换为全屏“视频”短剧流，并按已确认的竞品线框实现竖向分页、首集自动播放和可用状态兜底。

## 范围与约束

- 只修改 `/Users/mark/Documents/ChatGPT/剧有戏/前端` 的 Flutter 代码、测试和依赖；不修改 `/数据库`。
- 复用现有 `LibraryApi`、`DramaCard` 的数据访问和 `SearchPage` 的搜索逻辑；搜索改为视频页顶部胶囊打开的底部搜索面板，不再占用 Tab。
- 从剧集 JSON 的常见字段 `videoUrl`、`url`、`playUrl`、`m3u8` 读取首集视频地址；缺少合法 `http(s)` 地址时不伪造播放，展示“本集视频暂不可用”和可用海报。
- 使用 Flutter 原生 `PageView` 做竖向分页；只有当前页初始化并播放 `video_player` 控制器，离开页面暂停并释放控制器。
- 视频页隐藏全局底部 NavigationBar；左上角返回回到首页。所有可点击元素保留至少 48dp 触控区和语义标签。
- 不生成截图；验证使用测试、静态分析、构建和端口监听检查。

## 文件边界

- 修改 `前端/lib/src/models.dart`：新增 `Episode` 与 `Drama.episodes`，解析首集封面、标题和播放地址。
- 修改 `前端/pubspec.yaml`：仅新增已缓存的 `video_player` 依赖。
- 新增 `前端/lib/src/video_feed.dart`：封装视频页、单页播放器、静态海报/不可用状态、顶部/右侧/底部叠加层。
- 修改 `前端/lib/main.dart`：将 Tabbar 第二项改为“视频”，接入 `VideoFeedPage`，将现有搜索页作为视频顶部搜索面板复用。
- 修改 `前端/test/library_api_test.dart`：先写 Episode 解析与无地址兜底测试。
- 修改 `前端/test/widget_test.dart`：先写“视频”导航与不可用状态 smoke test。

## 实施顺序（TDD）

- [x] 先新增模型和 Widget 的失败测试，运行 `flutter test` 确认红灯。
- [x] 实现 Episode 解析、依赖和视频页最小可用 UI，运行同一组测试转绿。
- [x] 接入 AppShell：视频页选中时隐藏底栏，顶部搜索复用已有 `SearchPage`，返回恢复首页。
- [x] 运行 `dart format`、`dart analyze .`、`flutter test`、`flutter build ios --debug --no-codesign`；Android 构建因机器没有 Android SDK 未执行成功。
- [x] 检查 9000/9010 监听和源码中无凭据；按现有启动入口恢复 9010 内存模式并保持运行。

## 验收标准

- Tabbar 显示“首页 / 视频 / 追剧 / 我的”，不再显示“搜索”。
- 视频页使用黑色全屏舞台、竖向一页一剧、首集海报与自动播放；上下滑动只切换当前页。
- 没有视频地址时不出现播放错误或假链接，用户能读到明确的不可用状态。
- 未知集数、播放量、互动数不被渲染成 `unknown`、`null` 或虚假数字。
- 现有首页、追剧、我的和 API 测试保持通过。
