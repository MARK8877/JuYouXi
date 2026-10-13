# 追剧热播区排序与上拉分页实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 追剧页“正在热播”按播放量/热度降序展示，每批 15 部，最多 10 批并在上拉至底部时继续显示。

**Architecture:** 复用追剧页现有 `fetchDramas()` 返回的剧库和竖向 `CustomScrollView`。前端先稳定排序，优先解析热度 `heat`，缺失时回退播放量 `views`，未知值排末尾；网格初始展示 15 条，接近滚动底部再展开下一批，最多展示前 150 条，不增加接口或依赖。

**Tech Stack:** Flutter/Dart 现有页面与 widget tests；无新增依赖。

**Spec:** 用户请求：追剧页正在热播按播放热度从高到低，最多 10 页、每页 15 部，上拉加载更多。

## 全局约束

- 只改追剧页正在热播区及对应测试；不改首页、播放器或其他追剧区。
- 每页 15 条，最多 10 页（150 条）。
- 复用现有 API 全量数据；不添加分页接口或依赖。
- 保持原有双列网格与短剧点击详情行为。

---

### Task 1：排序、页大小与上限

**Files:**
- Modify: `前端/lib/main.dart`
- Test: `前端/test/widget_test.dart`

**接口:**
- `buildHotDramas(Iterable<Drama>)` 返回稳定排序且最多 150 部的热播列表；heat 优先，heat 不可解析时使用 views，均不可解析时排末尾。

- [ ] 先写测试：高 heat 短剧排前、heat 缺失时使用 views、未知数据排末尾、重复热度保持源顺序、结果最多 150 部。
- [ ] 运行测试，确认因 `buildHotDramas` 缺失而失败。
- [ ] 实现排序与 150 条上限。
- [ ] 运行目标测试确认通过。

### Task 2：上拉分批加载

**Files:**
- Modify: `前端/lib/main.dart`
- Test: `前端/test/widget_test.dart`

- [ ] 先写 widget test：初次网格显示 15 部；上拉接近底部后增至 30 部；最多增至 150 部且不再增长。
- [ ] 运行测试确认分页行为当前失败。
- [ ] 在现有竖向滚动容器接入底部阈值监听，每次只展开下一批 15 部；销毁页面时释放滚动控制器。
- [ ] 当列表耗尽或达到 150 部时显示结束提示；保持空态与短剧点击详情行为。
- [ ] 运行目标 widget test 与已有 Flutter tests。

### Task 3：最终核验

- [ ] 检查 diff 仅涉及本计划页面与测试；确认没有新增依赖和接口。
- [ ] 若 Flutter SDK 权限阻止测试，记录具体限制，不声称通过。
