# 紧凑首页海报与分类栏 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 缩短首页海报区域、让海报横向贴边，并把短剧类型栏改成轻量、无底色且可横向滚动的选择器。

**Architecture:** 继续复用 `HomePage` 的现有 `PageView`、分类数据和筛选状态，只调整首页布局尺寸与 `_CategoryRail` 的外观。正常字号下海报高度按屏幕高度约 42% 计算并限制在 340–440dp；大字号时按需增加空间。分类栏不增加依赖、不改变数据库计数或过滤行为。

**Tech Stack:** Flutter/Dart、现有 `flutter_test`。

**Spec:** 当前对话中用户确认的首页线框：海报横向贴边、约 42% 屏幕高度；分类栏透明背景、低矮横向滚动，选中项用细红色下划线。

## Global Constraints

- 仅修改 `前端/lib/main.dart`、`前端/test/widget_test.dart` 和本计划文件。
- 不增加依赖，不改 API、数据库、服务器状态或其他页面。
- 保留最多十部海报、海报详情导航、分类数据库数量、筛选和“正在上演”网格逻辑。
- 分类项触控区域正常字号至少 48dp，相邻选项至少间隔 8dp；支持大系统字体。
- 不截图。

---

### Task 1: 用 Widget tests 锁定首页尺寸与分类触控行为

**Files:**
- Modify: `前端/test/widget_test.dart`

**Interfaces:**
- Consumes: `HomePage`, 当前首页海报 `PageView` key，以及分类文字对应的横向 `ListView` 和 `InkWell`。
- Produces: 对海报宽度/高度、大字号扩展空间、分类栏高度及至少 48dp 点击区域的可运行回归测试。

- [x] 在现有 375×844 首页轮播测试中断言海报 `PageView` 左边缘为 0、宽度为 375，默认高度小于 400dp。
- [x] 扩展大字号首页测试，断言 2.0 倍系统字体下海报高度大于普通字号，且没有布局异常。
- [x] 在分类栏现有 Widget test 中断言正常字号横向列表高度为 56dp、一个分类 `InkWell` 的触控高度至少 48dp。
- [x] 分别运行上述定向测试并确认先因现有左右留白、过高布局或断言尺寸不符而失败。

### Task 2: 调整首页海报与类型栏

**Files:**
- Modify: `前端/lib/main.dart`

**Interfaces:**
- Consumes: `HomePage` 屏幕尺寸/字体缩放、`_featuredDramas`、`buildCategoryFilters` 和当前筛选回调。
- Produces: 横向无留白、字号自适应的紧凑 `_HomeHero`，以及无底色的 `_CategoryRail`。

- [x] 移除海报外层左右 Padding，保留顶部间距与当前圆角/内容。
- [x] 将默认海报高度改为屏幕高度 42%，正常范围限制为 340–440dp；系统字号放大时增加高度以保持标题和品牌区不重叠。
- [x] 将分类栏调整为正常字号 56dp；使用透明背景、横向滚动、图标与数据库计数、选中项红色文字及细下划线。
- [x] 保持每项至少 48dp 的触控高度、项间距至少 8dp，并随大系统字号增加可用高度。
- [x] 运行 Task 1 的定向测试并确认通过。

### Task 3: 回归与静态检查

**Files:**
- Modify: 无（除非定向测试暴露此范围内问题）。

**Interfaces:**
- Consumes: 首页布局与分类栏实现。
- Produces: 完整 Widget test 和 Dart analyzer 结果。

- [x] 运行 `flutter test test/widget_test.dart -r expanded`。
- [x] 运行 `dart analyze .`。
- [x] 检查改动仅影响首页海报和分类栏；确认分类数量、选择回调、详情导航及“正在上演”网格保持不变。
