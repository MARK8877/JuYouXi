# 首页海报安全区融合与短剧集数标签 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让首页海报无圆角并与透明状态栏无缝衔接，压缩分类栏到“正在上演”的间距、补充标题图标，并将已知总集数移到首页剧集封面左下角。

**Architecture:** 复用现有 `_HomeHero` 的图片与上下渐变层，通过 `SafeArea(top: false)` 和透明状态栏让海报延伸到系统状态栏后方，同时将安全区高度计入海报高度以保持原有底边位置。复用 `DramaCard`，新增仅由首页开启的集数角标选项；不改其他页面的卡片样式、数据接口或分类逻辑。

**Tech Stack:** Flutter/Dart、`AnnotatedRegion<SystemUiOverlayStyle>`、现有 `DramaCard`、`flutter_test`。

**Spec:** 当前对话中用户确认的线框：海报无圆角且延伸至透明状态栏；分类与“正在上演”间距约 8dp；标题左侧有播放图标；已知总集数以“68集”样式放在封面左下角，未知值不展示。

## Global Constraints

- 仅修改 `前端/lib/main.dart`、`前端/lib/src/drama_widgets.dart`、`前端/test/widget_test.dart` 和本计划文件。
- 不增加依赖，不改 API、数据库、服务器状态、其他页面或 `DramaCard` 默认行为。
- 保留海报轮播、搜索入口、迷你封面、分类筛选及“正在上演”剧数。
- 状态栏图标使用浅色，透明状态栏背景由海报顶部的暗色可读性渐变承接。
- 首页总集数只在 `episodeCount != null && episodeCount > 0` 时显示；未知数量不显示，也不在标题下重复显示集数。
- 不截图。

---

### Task 1: 锁定首页海报与区块标题布局

**Files:**
- Modify: `前端/test/widget_test.dart`

**Interfaces:**
- Consumes: `HomePage`, `_HomeHero` 的 PageView、`home-featured-title`、`正在上演` 标题。
- Produces: Widget tests for hero being edge-to-edge and square-cornered, transparent status bar over hero, compact section spacing, and decorative heading icon.

- [x] 将现有主页状态栏测试改为：`MediaQuery.padding.top = 24` 时，`home-featured-carousel` 顶边为 0，Home 的 `AnnotatedRegion<SystemUiOverlayStyle>` 状态栏颜色透明且图标为浅色，旧的独立纯色状态栏背景不存在。
- [x] 在 375×844 首页测试中断言主海报没有 `ClipRRect` 圆角祖先，且宽度仍与视口相同。
- [x] 扩展分类/首页测试，断言“正在上演”标题含有 keyed 播放图标，并且其顶部距分类栏底部不超过 10dp。
- [x] 先运行新增用例，确认旧版 `DramaCard` 缺少新角标参数导致编译失败；实现后定向测试通过。

### Task 2: 在首页封面展示已知总集数

**Files:**
- Modify: `前端/test/widget_test.dart`
- Modify: `前端/lib/src/drama_widgets.dart`

**Interfaces:**
- Consumes: `Drama.episodeCount`、`DramaCard` 现有 `showReleaseStatus` 开关。
- Produces: `DramaCard(showEpisodeCountOnCover: true)` 在封面左下角显示集数；默认 false 保持所有其他调用方不变。

- [x] 新增 Widget test：通过首页数据客户端确认已知集数在封面左下显示，且封面下方没有重复集数。
- [x] 新增 Widget test：`episodeCount` 缺失或非正数时无集数角标、无未知数值文本。
- [x] 运行新用例并确认旧版卡片接口未实现角标参数；实现后集数显示用例通过。
- [x] 在 `DramaCard` 新增默认关闭的 `showEpisodeCountOnCover`，仅对正的 `episodeCount` 渲染带深色半透明底的 `N集` 角标，并将可读集数纳入卡片语义标签。
- [x] 首页网格单独传 `showEpisodeCountOnCover: true`；开启时移除标题下原本包含集数/完成状态的副标题，默认调用方保持旧样式。
- [x] 运行已知集数、未知及零集数定向用例确认通过。

### Task 3: 实现状态栏融合与首页间距调整

**Files:**
- Modify: `前端/lib/main.dart`

**Interfaces:**
- Consumes: 当前 `HomePage` 安全区布局、`_HomeHero` 高度与品牌控件位置、`_CategoryRail`。
- Produces: 全宽直角海报延伸到 y=0；透明状态栏由海报渐变托底；“正在上演”间距约 8dp 且标题带播放图标。

- [x] 删除独立 `home-status-bar-background` 色块，用透明状态栏的 `AnnotatedRegion<SystemUiOverlayStyle>` 包裹首页。
- [x] 让滚动视图不避让顶部安全区，海报高度增加 `MediaQuery.padding.top + 8` 且品牌/搜索行 top 偏移相同值，以保留当前海报底边位置并避免控件与状态图标相撞。
- [x] 移除 `_HomeHero` 外层 `ClipRRect`，保留内部海报、上下渐变、文案、迷你封面、搜索与点击交互。
- [x] 将“正在上演”上方 padding 从 20dp 调为 8dp，并在标题左侧加入 22dp Vermilion 播放图标；计数仍靠右。
- [x] 运行 Task 1 的定向测试并确认通过。

### Task 4: 回归与可访问性检查

**Files:**
- Modify: 无（除非本范围测试发现问题）。

**Interfaces:**
- Consumes: 首页状态栏/海报/标题和首页集数角标实现。
- Produces: 完整 Widget test 与 Dart analyzer 结果。

- [x] 运行 `flutter test -r expanded`。
- [x] 运行 `dart analyze .`。
- [x] 核实新集数角标为 12sp、深色底上的白字满足对比度、角标仅在首页启用；检查顶部控件按安全区偏移并通过横屏滚动布局测试。
- [x] 确认不含 API/数据库/服务器变更，其他页面的 `DramaCard` 默认展示保持不变。
