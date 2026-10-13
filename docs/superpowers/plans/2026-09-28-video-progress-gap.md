# Compact Video Progress Gap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Set the visible gap from the discovery-video action row to its progress track to 10 Flutter logical pixels.

**Architecture:** Keep the compact progress bar's existing 36px touch area and 4px row spacing. Align only the compact track visual to the top of that area in both loading and initialized states; leave the full-size details slider and all callbacks unchanged.

**Tech Stack:** Flutter, Dart, flutter_test.

**Spec:** User-marked red rectangle between the bottom action row and progress line should be 10px high; all other behavior remains unchanged.

## Global Constraints

- Change only compact discovery progress-track positioning and its widget tests.
- Preserve slider drag behavior and the 36px touch area.
- Do not add dependencies, restart backend services, or take screenshots.

---

### Task 1: Align the compact progress track

**Files:**
- Modify: `前端/lib/src/video_feed.dart`
- Test: `前端/test/widget_test.dart`

**Interfaces:**
- Consumes: `VideoProgressBar(compact: true)` in the discovery feed.
- Produces: a visible progress-track top edge 10px after the action-row bottom, without shrinking its hit area.

- [x] Assert in widget tests that the loading and initialized compact track begin 10px below the action row while the touch area remains 36px; run and confirm failure.
- [x] Apply the smallest compact-only visual positioning change; leave details-page sizing and callbacks unchanged.
- [x] Run focused progress tests, the full Flutter test suite, Dart analysis, and formatting checks.
