# Library MySQL API Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create an independent Go service under `数据库/` that persists the verified `#library` data model in MySQL and documents its compatible HTTP API with OpenAPI.

**Architecture:** Keep the new service isolated from the running 9000 binary. Use `database/sql` with the MySQL driver, store the complete API payload as JSON alongside indexed library fields, and expose only the library-related routes verified from the existing page. Viewer-scoped following, history, and download submissions use a browser cookie; temporary playback URLs and credentials are never persisted.

**Tech Stack:** Go 1.21+, `net/http`, `database/sql`, `github.com/go-sql-driver/mysql`, MySQL 8-compatible SQL, OpenAPI 3.0 YAML.

**Spec:** Approved in chat on 2026-09-22.

## Global Constraints

- Only create or modify files below `/Users/mark/Documents/ChatGPT/剧有戏/数据库` for the generated project.
- Do not modify, stop, replace, or configure the real `/Users/mark/Downloads/人人剧库Go` service.
- Default new service port is `9010`; the existing `9000` service remains untouched.
- MySQL DSN comes only from `JUKU_MYSQL_DSN`; do not hard-code or persist passwords.
- Preserve the verified response field names and JSON shapes where the new service implements them.

---

### Task 1: Project skeleton and failing HTTP contract tests

**Files:**
- Create: `数据库/go.mod`
- Create: `数据库/internal/api/server_test.go`

**Interfaces:**
- Test the planned `api.NewServer(store)` constructor and library routes through `httptest`.

- [x] **Step 1: Write the failing tests**

  Cover `GET /health`, `GET /api/ui/viewer`, `GET /api/ui/dramas`, `GET /api/ui/search`, and `POST /api/ui/following` against an in-memory store fixture.

- [x] **Step 2: Run the tests and verify they fail because the API is not implemented**

  Run: `cd 数据库 && go test ./internal/api`

- [x] **Step 3: Keep the failure as the RED checkpoint**

  Do not add production handlers until the missing constructor/handler failure is observed.

### Task 2: MySQL schema and store

**Files:**
- Create: `数据库/schema.sql`
- Create: `数据库/internal/store/store.go`
- Create: `数据库/internal/store/store_test.go`

**Interfaces:**
- `Store.ListDramas(ctx, query) ([]Drama, error)`
- `Store.GetDrama(ctx, id) (Drama, bool, error)`
- `Store.UpsertDrama(ctx, drama) error`
- `Store.ListFollowing(ctx, viewerID) ([]Following, error)`
- `Store.UpdateFollowing(ctx, viewerID, input) (Following, error)`
- `Store.CreateDownloadTasks(ctx, viewerID, ids, quality) ([]DownloadTask, error)`

- [x] **Step 1: Add a store test for SQL-independent validation and payload round-trip**
- [x] **Step 2: Run `go test ./internal/store` and confirm the missing store implementation fails**
- [x] **Step 3: Add MySQL tables for dramas, library_sources, viewers, following, playback_history, download_tasks, ranking_boards, and ranking_items**
- [x] **Step 4: Implement parameterized MySQL queries and JSON payload round-tripping**
- [x] **Step 5: Run the store tests and `go test ./...`**

### Task 3: Compatible API handlers

**Files:**
- Create: `数据库/internal/api/models.go`
- Create: `数据库/internal/api/server.go`
- Modify: `数据库/internal/api/server_test.go`

**Interfaces:**
- `GET /health`
- `GET /api/ui/viewer`
- `GET /api/ui/dramas`
- `GET /api/ui/search`
- `POST /api/ui/dramas/refresh`
- `POST /api/ui/cover/repair`
- `GET|POST /api/ui/following`
- `POST /api/ui/download`
- `GET /api/ui/rankings`
- `POST /api/ui/recommendations`

- [x] **Step 1: Extend tests for validation, viewer cookie isolation, and response field names**
- [x] **Step 2: Run the focused API tests and verify the new cases fail**
- [x] **Step 3: Implement the smallest handlers over the store interface**
- [x] **Step 4: Add safe input limits and consistent JSON errors**
- [x] **Step 5: Run focused and full Go tests**

### Task 4: Server entrypoint and initialization

**Files:**
- Create: `数据库/cmd/server/main.go`
- Create: `数据库/README.md`

**Interfaces:**
- `JUKU_MYSQL_DSN` selects the database connection.
- `JUKU_ADDR` selects the listener, default `:9010`.

- [x] **Step 1: Add startup wiring and schema migration execution**
- [x] **Step 2: Run `go test ./...` and `go build ./cmd/server`**
- [x] **Step 3: Verify `/health` without connecting to an external MySQL instance by using the store constructor tests**

### Task 5: OpenAPI documentation and final verification

**Files:**
- Create: `数据库/openapi.yaml`

- [x] **Step 1: Document every verified library route, parameters, request bodies, response schemas, and error responses**
- [x] **Step 2: Validate YAML syntax with the available local tooling**
- [x] **Step 3: Run `gofmt`, `go test ./...`, and `go build ./cmd/server`**
- [x] **Step 4: Inspect generated files and verify port 9000 remains owned by the original process**
