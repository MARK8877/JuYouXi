# 剧有戏首页分类轨道 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (or subagent-driven-development) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将首页顶部分类区改成带图标的深色单行横向滚动选择轨道，顺序固定为追剧历史、精选榜、推荐、剧场、逆袭。

**Architecture:** 复用现有 `HomePage` 的 `_BrandHeader` 和 `_CategoryRail`，只替换顶部视觉与分类项渲染；继续由 `_category` 控制本地筛选，不新增 API、图片资源或状态管理。Material 矢量图标作为可替换的本地默认图标，避免引入花瓣资源抓取与版权依赖。

**Tech Stack:** Flutter Material 3、现有主题色、Material Icons；不增加依赖。

**Spec:** 已确认的深色顶部 + 图标胶囊 + 单行左右滚动线框（2026-09-23 对话，用户回复 `1`）。

## Global Constraints

- 只修改 `/Users/mark/Documents/ChatGPT/剧有戏/前端/lib/main.dart` 与对应 widget 测试。
- 不修改 API、数据库、视频流、追剧、我的和详情页逻辑。
- 分类轨道保持至少 48dp 触控高度、语义标签、明确选中态和横向滚动。
- 未接入历史/榜单数据时不伪造内容；点击后沿用现有本地筛选，匹配不到时显示现有空状态。
- 不截图验证；用 widget test、分析和构建验证。

## TDD Tasks

1. **Red tests**
   - [x] 在 `前端/test/widget_test.dart` 断言五个固定分类标签存在，并断言“搜索”不回到底部 Tab。
   - [x] 运行 `flutter test` 确认新增分类断言失败。

2. **Implementation**
   - [x] 固定分类顺序并为每项配置 Material 图标。
   - [x] 将 `_CategoryRail` 改为深色背景、图标+文字胶囊、单行横向滚动和选中态动画。
   - [x] 收紧 `_BrandHeader` 与分类轨道的视觉衔接，保留搜索入口和现有筛选回调。

3. **Verification**
   - [x] `dart format lib test`
   - [x] `dart analyze .`
   - [x] `flutter test`
   - [x] `flutter build ios --debug --no-codesign`
   - [x] 检查 9000/9010 listener 与源码无凭据变更。

## Acceptance Criteria

- 首页顶部显示五个分类：追剧历史、精选榜、推荐、剧场、逆袭，顺序不变。
- 分类项为图标+文字，单行左右滚动，不显示右侧“更多”入口。
- 推荐默认选中，其他项点击有清晰选中态，首页网格仍沿用原有本地过滤逻辑。
- 触控和语义满足移动端可访问性，不影响其他 Tab 与视频页。
