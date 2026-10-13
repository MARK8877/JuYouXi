# Per-Episode Engagement Implementation Plan

> **For agentic workers:** Use this plan task-by-task with inline execution. Every feature step follows TDD: add a failing test, verify RED, implement the minimum, verify GREEN.

**Goal:** Persist independent 1,000–9,999 simulated action counts per episode and keep episode selection from interrupting playback.

**Architecture:** Add an idempotent preload endpoint backed by a composite-key episode table. Reuse the current ten-minute worker cadence for per-episode growth, expose the values on Flutter's `Episode`, preload current/next counts without blocking playback, and bypass the pause path when opening the details page's episode picker.

**Tech Stack:** Go `database/sql`, MySQL/InnoDB, Flutter/Dart, existing HTTP client and `video_player`.

**Spec:** `docs/superpowers/specs/2026-10-13-per-episode-engagement.md`

## Global Constraints

- Keep existing drama-level engagement endpoint intact.
- Add no package dependencies or unrelated page/UI changes.
- Do not stop or restart the running server; do not apply live database migrations.
- Generate once per `(drama_id, episode_number)` and preserve counts on repeated preload requests.

---

### Task 1: Episode-scoped storage and preload API

**Files:**
- Modify: `数据库/internal/store/store.go`
- Modify: `数据库/internal/store/engagement.go`
- Modify: `数据库/internal/store/store_test.go`
- Modify: `数据库/internal/api/server.go`
- Modify: `数据库/internal/api/server_test.go`
- Modify: `数据库/schema.sql`
- Modify: `数据库/openapi.yaml`
- Modify: `数据库/cmd/server/main.go`

**Interfaces:**
- `Store.PreloadEpisodeEngagement(context.Context, string, int) (EpisodeEngagement, error)` validates identity and creates or returns the stable row.
- `EpisodeEngagement` contains `dramaId`, `episodeNumber`, four counts, and timestamps.
- `POST /api/ui/episode-engagement` accepts `dramaId` and positive `episodeNumber`, validates the drama, and returns those fields.
- `AdvanceEngagementGrowth` advances due episode rows on the existing ten-minute ticker.

- [x] Write store tests for range, idempotency, per-episode isolation, and growth cadence; run `go test ./internal/store` and verify the new tests fail because the new store method/type do not exist.
- [x] Write API tests for successful preload, stable repeated response, invalid episode, and missing drama; run `go test ./internal/api` and verify failures are due to the absent route/behavior.
- [x] Implement the memory/MySQL store method, additive table, handler, OpenAPI schema/operation, and due-row growth. Keep legacy drama-level code untouched.
- [x] Run `go test ./...` from `数据库` and require all tests to pass.

### Task 2: Flutter episode model and preload client

**Files:**
- Modify: `前端/lib/src/models.dart`
- Modify: `前端/lib/src/library_api.dart`
- Modify: `前端/test/library_api_test.dart`

**Interfaces:**
- `Episode` stores `likes`, `comments`, `favorites`, and `shares` and can copy those values without losing playback metadata.
- `LibraryApi.preloadEpisodeEngagement(String dramaId, int episodeNumber)` posts the preload request and parses the response as episode-scoped engagement data.

- [x] Add tests that parse episode counts and assert the exact POST path/body; verify the missing preload method with analyzer output before implementation. The initial Flutter invocation was blocked by SDK-cache permissions.
- [x] Add episode count fields/copy support and the preload method.
- [x] Run the focused API test, `dart format --output=none --set-exit-if-changed lib/src/models.dart lib/src/library_api.dart test/library_api_test.dart`, and static analysis from `前端`.

### Task 3: Playback preload and picker behavior

**Files:**
- Modify: `前端/lib/src/video_feed.dart`
- Modify: `前端/test/widget_test.dart`

**Interfaces:**
- Active playback state uses the selected `Episode` counters; preloading current and next episode is fire-and-forget and cannot delay HLS playback.
- The existing one-minute UI refresh reads the selected episode through the idempotent preload endpoint.
- `_openEpisodeControls` pauses only when the action leaves the feed for the details route; the details-page picker opens without pause. Existing page activation continues to start the newly selected episode.

- [x] Add a widget regression test with a fake video-player platform; it failed first because opening the picker paused playback.
- [x] Implement per-episode counts in the action rail/comment heat, preload current and next episodes without awaiting them, and skip pause before the in-page episode picker.
- [x] Run the focused widget test, formatter, and static analysis. The focused regression passes.

### Task 4: Cross-project verification

**Files:** No additional files.

- [x] Run `go test ./...` in `数据库`.
- [x] Run `dart analyze lib/main.dart test/library_api_test.dart test/widget_test.dart` in `前端`.
- [x] Run Flutter tests: the API suite and focused playback regression pass; the full widget suite has one isolated, unrelated assertion failure at `test/widget_test.dart:1735` (expected one “暂无播放量数据”, found two), reproduced when run alone.
- [x] Review the changed implementation files and OpenAPI YAML syntax; leave the running server untouched.
