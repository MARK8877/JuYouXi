# Video Content Drop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move the video title/episode/description and bottom playback controls to a total 20px offset.

**Architecture:** Reuse `_videoContentDrop` in `前端/lib/src/video_feed.dart`; update existing widget geometry expectations and keep the description layer above the anchored footer backdrop in `前端/test/widget_test.dart`. No new UI abstraction or dependency.

**Tech Stack:** Flutter, Dart, flutter_test.

**Spec:** User request: lower the short-drama title, episode, description, total-episode/free-watch, playback-speed, and fullscreen controls by 20px.

## Global Constraints

- Change only the shared video-content offset and its geometry tests.
- Preserve bottom background anchoring, control spacing, hit areas, and playback behavior.
- Do not restart or modify backend services; do not take screenshots.

---

### Task 1: Apply the 20px video content offset

**Files:**
- Modify: `前端/lib/src/video_feed.dart:14`
- Test: `前端/test/widget_test.dart:445-560`

**Interfaces:**
- Consumes: the existing `_videoContentDrop` used by the video description and bottom-controls content.
- Produces: 20px total displacement while preserving the anchored bottom-controls background.

- [x] Update the existing geometry assertions to expect the description 10px lower and controls 10px lower than their current 10px positions; assert the description layer paints above the footer backdrop while remaining above the action row; run focused widget tests and verify they fail.
- [x] Change `_videoContentDrop` from `10.0` to `20.0` and order the description overlay above the footer backdrop.
- [x] Run the focused geometry tests, then the full widget test suite and Dart analysis.
