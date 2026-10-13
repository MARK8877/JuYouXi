# 追剧页最高热度推荐 Implementation Plan

> **For agentic workers:** Inline execution in the current task; do not delegate.

**Goal:** 在追剧页以紧凑提示区展示数据库中热度最高的最多 12 部短剧，以每页 2×2 的方式横向分页三屏，并复用详情跳转。

**Architecture:** 复用追剧页已经加载的剧库数据，前端按 `Drama.heat` 中的数值排序并过滤未知热度。推荐区使用带四周留白的小型封面行卡；顶部分段按钮与现有非循环 `PageView` 共用页状态，不新增服务端接口、依赖或播放器逻辑。

**Tech Stack:** Flutter / Dart、flutter_test。

**Spec:** 当前任务中用户已确认的线框：筛选栏下方、追剧清单上方；上下左右留白的紧凑提示卡；2 列 × 2 行；最多 12 部、非循环横向分页；卡片顶部分段按钮与横向滑动同步；现有追剧列表筛选语义不变；未知热度不伪造。

## Global Constraints

- 仅修改追剧页和对应测试，不改变其他 Tab 或追剧清单筛选逻辑。
- 复用现有剧库接口、`DramaCard` 和详情页路由，不加依赖。
- 最高热度排序基于 `Drama.heat`；无法解析的热度不进入榜单。
- 少于 12 条有效记录时展示可用记录，不补造数据。
- 推荐提示卡在手机宽度下左右各留 16 px，整体高度小于 280 px。

---

### Task 1: 热度排序与追剧页推荐分页

**Files:**
- Modify: `前端/lib/main.dart`
- Test: `前端/test/widget_test.dart`

**Interfaces:**
- Produces: `buildTopHeatRecommendations(Iterable<Drama>) -> List<Drama>`，按解析热度降序、同热度保持原顺序、最多返回 12 条。
- Consumes: `LibraryApi.fetchDramas()`、现有 `DramaCard`、`ShortDramaDetailsPage`。

- [x] **Step 1: Write failing behavior tests**

  Add a widget test whose API fixture returns 13 numeric heat values (including `万` values) and one `unknown`; assert the first, second, and third pages show the top 12 in descending order and the page indicator advances.

- [x] **Step 2: Run the focused tests and confirm failure**

  Run `flutter test test/widget_test.dart --plain-name 'shows twelve hottest dramas in three swipeable 2x2 pages'` from `前端`; it failed because the recommendation page was absent.

- [x] **Step 3: Implement the minimal behavior**

  Add the pure ranking helper in `main.dart`, parsing numeric heat values and the `万` / `亿` suffixes; skip unparseable values, keep equal values in input order, and take 12. In `FollowingPage`, derive pages of four from the already-fetched catalog and add a non-looping `PageView` with a 2×2 `DramaCard` grid and page dots between the filters and existing followed-drama content. Tapping a card opens the existing detail route at episode one. Keep the existing saved-list empty state below the recommendations.

- [x] **Step 4: Run focused tests, then the full suite and analyzer**

  The focused widget test and full `flutter test` suite pass. `dart analyze` reported `No issues found!`, then exited 1 while trying to touch the telemetry session under the non-writable user directory; `flutter analyze` separately hit a Dart analysis-server URI `FormatException` in this Chinese-named path.

### Task 2: 收紧推荐提示区并联动分页分段

**Files:**
- Modify: `前端/lib/main.dart`
- Test: `前端/test/widget_test.dart`

**Interfaces:**
- Consumes: `_recommendationPageController`, `_recommendationPage`、现有追剧筛选状态及推荐分页数据。
- Produces: keyed recommendation panel and page segments; tapping a segment navigates to that page, and swiping updates the selected segment.

- [x] **Step 1: Add failing widget assertions**

  Extend the existing recommendation widget test with panel geometry and page-segment interaction:

```dart
final panel = find.byKey(const ValueKey('following-hot-panel'));
final panelRect = tester.getRect(panel);
expect(panelRect.left, closeTo(16, .01));
expect(panelRect.right, closeTo(374, .01));
expect(panelRect.height, lessThan(280));

final secondSegment = find.byKey(
  const ValueKey('following-hot-page-segment-1'),
);
await tester.tap(secondSegment);
await tester.pumpAndSettle();
expect(find.bySemanticsLabel('第2页，共3页'), findsOneWidget);
expect(tester.widget<Semantics>(secondSegment).properties.selected, isTrue);
```

- [x] **Step 2: Run the focused test and confirm expected failure**

  Run `flutter test test/widget_test.dart --plain-name 'shows twelve hottest dramas in three swipeable 2x2 pages'` from `前端`; it should fail because the compact panel and linked page segments are not present yet.

- [x] **Step 3: Implement only the compact panel and segment linkage**

  Replace the large portrait-card grid with a padded, rounded panel containing four compact horizontal items per page. Keep two columns, heat ranking, tap-to-detail, existing list filters, and the same `PageView`. Add page segments in the panel header; their taps call `animateToPage`, and `onPageChanged` continues to update the shared selected index.

- [x] **Step 4: Run focused and full verification**

  The focused widget test and full `flutter test` suite pass (53 tests). `dart analyze` reports `No issues found!`.
