# 首页海报轮播与个人页顶部背景 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the homepage's text-only top header with an accessible poster carousel sampled from up to ten loaded dramas, hide release-status badges on homepage grid covers, and make the profile status/header backgrounds a single continuous gradient.

**Architecture:** Keep `HomePage` as the owner of loaded and featured drama state. Select a shuffled copy once after each successful fetch, render it with Flutter's built-in `PageView`, and reuse the existing `_showDetails` route for the hero and mini posters. Add one opt-out flag to the shared `DramaCard`, enabled only by the homepage. Reuse one horizontal gradient value for the profile status region and personal-information header.

**Tech Stack:** Flutter/Dart, built-in `PageView`, existing `LibraryApi`, `flutter_test`, and the existing HTTP test client pattern.

**Spec:** `docs/superpowers/specs/2026-09-24-home-hero-carousel.md`

## Global Constraints

- Touch only `前端/lib/main.dart`, `前端/lib/src/drama_widgets.dart`, and `前端/test/widget_test.dart` for implementation.
- Add no package dependencies and do not change API/database behavior.
- Preserve search, category filtering, the “正在上演” grid, detail navigation, and SearchPage release badges.
- Choose at most ten unique dramas once per successful load; ordinary rebuilds must not reshuffle.
- Hero and mini posters use the current first-episode detail route; do not fabricate actor/lock/exclusive metadata.
- Personal profile controls and scrolling stay unchanged; only the status/header background rendering changes.
- Do not start or stop servers and do not capture screenshots.

---

### Task 1: Lock homepage carousel and badge behavior with widget tests

**Files:**
- Modify: `前端/test/widget_test.dart`

**Interfaces:**
- Consumes: `HomePage`, `DramaCard`, `LibraryApi`, `ShortDramaDetailsPage`.
- Produces: Widget tests for a ten-item maximum carousel, poster-to-details navigation, and homepage-only status-badge suppression.

- [x] Add a fake `http.BaseClient` that returns 12 dramas at `/api/ui/dramas`, each with two episodes and `releaseStatus: "finish"`, and returns a handled playback-open failure for detail navigation.
- [x] Add tests asserting the keyed homepage `PageView` has exactly 10 items, a horizontal swipe changes the feature, and both main and mini posters push `ShortDramaDetailsPage`.
- [x] Add a test that scrolls the homepage grid into view and asserts the standalone `finish` badge text is absent.
- [x] Add a shared-card test proving release badges remain enabled by default outside the homepage.
- [x] Run `flutter test test/widget_test.dart --plain-name "samples at most ten dramas"` and `flutter test test/widget_test.dart --plain-name "release badge"` from `前端/`.
- [x] Confirm both fail because the requested carousel and badge opt-out do not exist yet.

### Task 2: Implement the hero and scoped badge option

**Files:**
- Modify: `前端/lib/main.dart`
- Modify: `前端/lib/src/drama_widgets.dart`

**Interfaces:**
- Consumes: existing drama loading, category filtering, `LibraryApi.coverUrl`, and `_showDetails`.
- Produces: a private homepage hero carousel in `HomePage`; `DramaCard(showReleaseStatus: true)` by default.

- [x] Store `_featuredDramas` in `_HomePageState` and `_currentIndex` in the hero; in preview mode use its existing sample, and on successful fetch deduplicate, copy, shuffle, and take no more than ten dramas.
- [x] Replace only `_BrandHeader` placement with a clipped `PageView` hero, inset 12pt horizontally. Overlay retained brand/search controls at the top; show current title and available category/episode metadata over a bottom readability gradient.
- [x] Show up to two other sampled drama covers as 48pt+ tappable mini posters, and show labelled pagination dots that stay in sync with swipes.
- [x] Route every poster through the existing `_showDetails` method.
- [x] Add `showReleaseStatus` to `DramaCard`, default `true`, key the badge, and pass `false` only from the homepage grid.
- [x] Run the two targeted widget tests and verify they pass before refactoring.

### Task 3: Unify the profile status and personal-information gradient

**Files:**
- Modify: `前端/lib/main.dart`
- Test: `前端/test/widget_test.dart`

**Interfaces:**
- Consumes: `_profileHeaderTop`, `_profileHeaderBottom`, `_ProfileHero`, and `ProfilePage`'s status-bar background.
- Produces: one shared left-to-right gradient for the status region and profile hero; transparent system status-bar color so the Flutter gradient remains visible.

- [x] Add a widget test that asserts the status region and `profile-hero` use identical gradient begin/end/colors and that `SystemUiOverlayStyle.statusBarColor` is transparent.
- [x] Run `flutter test test/widget_test.dart --plain-name "profile status bar uses the header gradient"` and confirm it fails because the status region is currently solid-colored.
- [x] Define one `const LinearGradient` from `_profileHeaderTop` to `_profileHeaderBottom`, both horizontally aligned, and apply it to the status background and `_ProfileHero`.
- [x] Set the profile `AnnotatedRegion` status bar color to transparent; preserve its light status-bar icons.
- [x] Re-run the targeted profile test.

### Task 4: Regression and accessibility verification

**Files:**
- Modify: none unless a regression is found in the scoped implementation files.

**Interfaces:**
- Consumes: the implementation and existing widget suite.
- Produces: passing test/analyzer evidence.

- [x] Run `flutter test test/widget_test.dart -r expanded` from `前端/`.
- [x] Run `dart analyze .` from `前端/`.
- [x] Verify the hero at 375px width and large text; check the 48pt search target, 60pt mini-poster targets, page-indicator label, and readable text against its scrim.
- [x] Review the diff to ensure SearchPage badges and unrelated pages were not changed.
