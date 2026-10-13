# 追剧页参照图改版 Implementation Plan

> **For agentic workers:** Execute in this session with test-first checks. Keep existing backend and other tabs unchanged.

**Goal:** Build the approved dark following page with the five highest-viewed dramas in the hero and “猜你在追” sections, five random recommendations, and no page navigation controls.

**Architecture:** Reuse `LibraryApi.fetchDramas()` for discovery sections, and keep the existing following/history endpoints for the saved list and watched episode. Derive the view-count ranking and random recommendation sample in pure functions, and render them in `FollowingPage`. Retain the existing following collection behind “查看全部”.

**Tech Stack:** Flutter, Dart, existing `http` and `flutter_test` dependencies.

**Spec:** User-approved wireframe and four data rules in this conversation (2026-10-13).

## Global Constraints

- Only modify the following page, its data selection, and focused tests.
- Preserve saved-following navigation and removal behind “查看全部”.
- Do not invent view counts, recommendation flags, or exclusive badges.
- Display play counts after dividing by 1000 and label them in thousands of plays.
- The existing homepage “推荐” pool is the drama library; take five unique random entries on load/refresh.
- No page dots, pagination buttons, or page-based hot recommendations.

---

### Task 1: Data selection

**Files:** Modify `前端/lib/src/models.dart`, `前端/lib/main.dart`, `前端/test/widget_test.dart`.

**Interfaces:** `buildMostViewedDramas(dramas)`; `formatPlayCount(value)`; `pickRandomRecommendedDramas(dramas, random)`.

- [x] Reuse the existing view-count ranking test for both hero and “猜你在追”.
- [x] Add a test with `views` such as `1.2万`, `9800`, `unknown`; expect the first five numeric leaders and no unknown count.
- [x] Display parsed play counts as the original count divided by 1000, with a “千次播放” unit.
- [x] Add a seeded-random test that returns five unique dramas from the input library and never changes the input order.
- [x] Run the focused tests and confirm failures in the missing behavior.
- [x] Reuse the existing `views` field and share the sorted top-five list between the hero and horizontal rail.

### Task 2: Following screen layout and interaction

**Files:** Modify `前端/lib/main.dart`, `前端/test/widget_test.dart`.

**Interfaces:** `FollowingPage` keeps the existing constructor and detail navigation. “查看全部” shows the existing saved-following list; “返回” restores the reference layout.

- [x] Replace the former pagination widget test with a widget test that checks the five matching hero items, most-viewed order, five hot cards, and absence of page dots.
- [x] Test that a hero poster tap opens the existing details page and “查看全部” still exposes the saved-following collection.
- [x] Run the focused widget tests and confirm the new expectations fail against the current page.
- [x] Render the compact dark hero, horizontal most-viewed rail and two-column hot grid; remove the old page controllers/dots.
- [x] Keep the bottom navigation dark only while the following tab is selected, leaving the other tabs' appearance as-is.
- [x] Rerun the focused widget tests, `dart analyze`, and Flutter tests. Resolve only failures caused by this change.

### Task 3: Final verification

**Files:** No new source files.

- [x] Check source scope and run an Android Flutter build to confirm compilation. (Web is not configured; all project files are untracked in the current Git root.)
- [x] Report the exact behavior and the current API data limitations.
