package api

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strconv"
	"strings"
	"time"

	"juku-library-db/internal/store"
)

const (
	viewerCookie   = "juku_viewer_id"
	sourceHongguo  = "hongguo"
	followingLimit = 1000
)

type Server struct {
	store       store.Store
	openapiSpec []byte
}

func NewServer(database store.Store) http.Handler {
	return NewServerWithSpec(database, nil)
}

func NewServerWithSpec(database store.Store, openapiSpec []byte) http.Handler {
	if database == nil {
		database = store.NewMemory()
	}
	server := &Server{store: database, openapiSpec: append([]byte(nil), openapiSpec...)}
	mux := http.NewServeMux()
	mux.HandleFunc("/health", server.handleHealth)
	mux.HandleFunc("/swagger", server.handleSwaggerRoot)
	mux.HandleFunc("/swagger/", server.handleSwagger)
	mux.HandleFunc("/api/ui/viewer", server.handleViewer)
	mux.HandleFunc("/api/ui/dramas", server.handleDramas)
	mux.HandleFunc("/api/ui/search", server.handleSearch)
	mux.HandleFunc("/api/ui/dramas/refresh", server.handleDramaRefresh)
	mux.HandleFunc("/api/ui/cover/repair", server.handleCoverRepair)
	mux.HandleFunc("/api/ui/following", server.handleFollowing)
	mux.HandleFunc("/api/ui/history", server.handleHistory)
	mux.HandleFunc("/api/ui/engagement", server.handleEngagementHeat)
	mux.HandleFunc("/api/ui/episode-engagement", server.handleEpisodeEngagement)
	mux.HandleFunc("/api/ui/comments", server.handleComments)
	mux.HandleFunc("/api/ui/download", server.handleDownload)
	mux.HandleFunc("/api/ui/rankings", server.handleRankings)
	mux.HandleFunc("/api/ui/recommendations", server.handleRecommendations)
	mux.HandleFunc("/api/ui/image", server.handleImage)
	return mux
}

func (s *Server) handleSwaggerRoot(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	http.Redirect(w, r, "/swagger/", http.StatusMovedPermanently)
}

func (s *Server) handleSwagger(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	if r.URL.Path == "/swagger/openapi.yaml" {
		if len(s.openapiSpec) == 0 {
			writeError(w, http.StatusNotFound, "openapi spec is not configured")
			return
		}
		// An inline HTML media type lets the source open as a top-level browser
		// document in clients that block raw JSON/YAML navigation. The response
		// body remains the original YAML and Swagger UI still parses it.
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.Header().Set("Content-Disposition", "inline")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write(s.openapiSpec)
		return
	}
	if r.URL.Path != "/swagger/" {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	_, _ = w.Write([]byte(swaggerHTML))
}

const swaggerHTML = `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>剧库 API Swagger 文档</title>
  <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css">
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
  <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-standalone-preset.js"></script>
  <script>
    window.onload = function () {
      window.ui = SwaggerUIBundle({
        url: '/swagger/openapi.yaml',
        dom_id: '#swagger-ui',
        deepLinking: true,
        presets: [SwaggerUIBundle.presets.apis, SwaggerUIStandalonePreset],
        layout: 'StandaloneLayout'
      });
    };
  </script>
</body>
</html>`

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": map[string]string{"status": "ok"}})
}

func (s *Server) handleViewer(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	id := viewerID(w, r)
	if err := s.store.TouchViewer(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, "无法保存浏览器身份")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"ready": true, "sources": []string{sourceHongguo}, "onlineOnly": false, "account": nil,
	})
}

func (s *Server) handleDramas(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	if source := strings.TrimSpace(r.URL.Query().Get("source")); source != "" && source != sourceHongguo {
		writeError(w, http.StatusBadRequest, "不支持该站源")
		return
	}
	dramas, err := s.store.ListDramas(r.Context(), store.DramaFilter{Source: sourceHongguo})
	if err != nil {
		writeError(w, http.StatusInternalServerError, "无法读取剧库")
		return
	}
	sources, revision, err := s.store.Sources(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, "无法读取剧库状态")
		return
	}
	if revision == 0 {
		revision = 1
	}
	loadedAt := time.Time{}
	if state := sources[sourceHongguo]; !state.UpdatedAt.IsZero() {
		loadedAt = state.UpdatedAt
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"revision":          revision,
		"loadedAt":          loadedAt,
		"loading":           false,
		"metadata":          map[string]any{"running": false, "checked": 0, "total": 0, "updated": 0, "failed": 0},
		"metadataRemaining": map[string]int{"": 0, sourceHongguo: 0},
		"sources":           sources,
		"data":              dramas,
	})
}

func (s *Server) handleSearch(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	keyword := strings.TrimSpace(r.URL.Query().Get("q"))
	if keyword == "" || len(keyword) > 256 {
		writeError(w, http.StatusBadRequest, "搜索词无效")
		return
	}
	dramas, err := s.store.ListDramas(r.Context(), store.DramaFilter{Source: sourceHongguo, Search: keyword})
	if err != nil {
		writeError(w, http.StatusInternalServerError, "无法搜索剧库")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"query": keyword, "data": dramas, "total": len(dramas), "saved": true})
}

func (s *Server) handleDramaRefresh(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	var input struct {
		DramaID string `json:"dramaId"`
	}
	if !decodeJSON(w, r, &input) || strings.TrimSpace(input.DramaID) == "" {
		return
	}
	drama, found, err := s.store.GetDrama(r.Context(), input.DramaID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "无法读取剧集资料")
		return
	}
	if !found {
		writeError(w, http.StatusNotFound, "剧库中没有该剧集")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"dramaId": input.DramaID, "drama": drama, "retryAfter": 300})
}

func (s *Server) handleCoverRepair(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	var input struct {
		DramaID string `json:"dramaId"`
		Cover   string `json:"cover"`
	}
	if !decodeJSON(w, r, &input) || strings.TrimSpace(input.DramaID) == "" {
		return
	}
	drama, found, err := s.store.GetDrama(r.Context(), input.DramaID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "无法读取剧集资料")
		return
	}
	if !found {
		writeError(w, http.StatusNotFound, "剧库中没有该剧集")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"dramaId": input.DramaID, "cover": dramaCover(drama), "retryAfter": 300})
}

func (s *Server) handleFollowing(w http.ResponseWriter, r *http.Request) {
	id := viewerID(w, r)
	if err := s.store.TouchViewer(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, "无法保存浏览器身份")
		return
	}
	switch r.Method {
	case http.MethodGet:
		entries, err := s.store.ListFollowing(r.Context(), id)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "无法读取追剧清单")
			return
		}
		data := make([]map[string]any, 0, len(entries))
		for _, entry := range entries {
			data = append(data, map[string]any{
				"dramaId": entry.DramaID, "source": entry.Source, "title": entry.Title, "category": entry.Category,
				"saved": entry.Saved, "completed": entry.Completed, "knownEpisodes": entry.KnownEpisodes,
				"totalEpisode": entry.KnownEpisodes, "newEpisodes": 0, "addedAt": entry.AddedAt, "updatedAt": entry.UpdatedAt,
			})
		}
		writeJSON(w, http.StatusOK, map[string]any{"data": data, "limit": followingLimit})
	case http.MethodPost:
		var input struct {
			DramaID     string `json:"dramaId"`
			Saved       *bool  `json:"saved"`
			Completed   *bool  `json:"completed"`
			Acknowledge bool   `json:"acknowledge"`
		}
		if !decodeJSON(w, r, &input) {
			return
		}
		if input.DramaID == "" || input.Saved == nil && input.Completed == nil && !input.Acknowledge {
			writeError(w, http.StatusBadRequest, "追剧操作或剧集 ID 无效")
			return
		}
		entry, err := s.store.UpdateFollowing(r.Context(), id, store.FollowInput{DramaID: input.DramaID, Saved: input.Saved, Completed: input.Completed, Acknowledge: input.Acknowledge})
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "剧库中没有该剧集")
			return
		}
		if err != nil {
			writeError(w, http.StatusInternalServerError, "追剧操作未保存")
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"ok": true, "entry": entry})
	default:
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (s *Server) handleHistory(w http.ResponseWriter, r *http.Request) {
	id := viewerID(w, r)
	if err := s.store.TouchViewer(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, "无法保存浏览器身份")
		return
	}
	switch r.Method {
	case http.MethodGet:
		entries, err := s.store.ListPlaybackHistory(r.Context(), id)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "无法读取观看记录")
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"data": entries})
	case http.MethodPost:
		var input struct {
			DramaID         string `json:"dramaId"`
			EpisodeNumber   int    `json:"episodeNumber"`
			PositionSeconds int    `json:"positionSeconds"`
			DurationSeconds int    `json:"durationSeconds"`
		}
		if !decodeJSON(w, r, &input) {
			return
		}
		entry, err := s.store.RecordPlaybackHistory(r.Context(), id, store.PlaybackHistoryInput{
			DramaID:         input.DramaID,
			EpisodeNumber:   input.EpisodeNumber,
			PositionSeconds: input.PositionSeconds,
			DurationSeconds: input.DurationSeconds,
		})
		if errors.Is(err, store.ErrInvalidInput) {
			writeError(w, http.StatusBadRequest, "观看记录参数无效")
			return
		}
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "剧库中没有该剧集")
			return
		}
		if err != nil {
			writeError(w, http.StatusInternalServerError, "观看记录未保存")
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"ok": true, "entry": entry})
	default:
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (s *Server) handleComments(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		dramaID := strings.TrimSpace(r.URL.Query().Get("dramaId"))
		comments, err := s.store.ListComments(r.Context(), dramaID)
		if errors.Is(err, store.ErrInvalidInput) {
			writeError(w, http.StatusBadRequest, "短剧 ID 无效")
			return
		}
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "剧库中没有该短剧")
			return
		}
		if err != nil {
			writeError(w, http.StatusInternalServerError, "无法读取评论")
			return
		}
		writeJSON(w, http.StatusOK, map[string]any{"dramaId": dramaID, "data": comments, "total": len(comments)})
	case http.MethodPost:
		viewerID := viewerID(w, r)
		if err := s.store.TouchViewer(r.Context(), viewerID); err != nil {
			writeError(w, http.StatusInternalServerError, "无法保存浏览器身份")
			return
		}
		var input struct {
			DramaID  string `json:"dramaId"`
			Content  string `json:"content"`
			ParentID string `json:"parentId"`
		}
		if !decodeJSON(w, r, &input) {
			return
		}
		comment, err := s.store.CreateComment(r.Context(), viewerID, store.DramaCommentInput{
			DramaID:  input.DramaID,
			Content:  input.Content,
			ParentID: input.ParentID,
		})
		if errors.Is(err, store.ErrInvalidInput) {
			writeError(w, http.StatusBadRequest, "评论内容无效或父评论不可回复，内容最多500个字符")
			return
		}
		if errors.Is(err, store.ErrNotFound) {
			writeError(w, http.StatusNotFound, "剧库中没有该短剧")
			return
		}
		if err != nil {
			writeError(w, http.StatusInternalServerError, "评论未保存")
			return
		}
		comments, err := s.store.ListComments(r.Context(), input.DramaID)
		if err != nil {
			writeError(w, http.StatusInternalServerError, "评论已保存但计数暂不可用")
			return
		}
		response := map[string]any{"data": comment, "total": len(comments)}
		if input.ParentID != "" {
			for _, item := range comments {
				if item.ID == input.ParentID {
					response["parentReplyCount"] = item.ReplyCount
					break
				}
			}
		}
		writeJSON(w, http.StatusOK, response)
	default:
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
	}
}

func (s *Server) handleEngagementHeat(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	dramaID := strings.TrimSpace(r.URL.Query().Get("dramaId"))
	if dramaID == "" {
		writeError(w, http.StatusBadRequest, "短剧 ID 无效")
		return
	}
	if _, found, err := s.store.GetDrama(r.Context(), dramaID); err != nil {
		writeError(w, http.StatusInternalServerError, "无法读取短剧")
		return
	} else if !found {
		writeError(w, http.StatusNotFound, "剧库中没有该短剧")
		return
	}
	heat, err := s.store.GetEngagementHeat(r.Context(), dramaID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "无法读取互动热度")
		return
	}
	response := map[string]any{
		"dramaId":   dramaID,
		"simulated": true,
		"likes":     heat.Likes,
		"comments":  heat.Comments,
		"favorites": heat.Favorites,
		"shares":    heat.Shares,
	}
	if !heat.UpdatedAt.IsZero() {
		response["updatedAt"] = heat.UpdatedAt
	}
	writeJSON(w, http.StatusOK, response)
}

func (s *Server) handleEpisodeEngagement(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	var input struct {
		DramaID       string `json:"dramaId"`
		EpisodeNumber int    `json:"episodeNumber"`
	}
	if !decodeJSON(w, r, &input) {
		return
	}
	input.DramaID = strings.TrimSpace(input.DramaID)
	if input.DramaID == "" || input.EpisodeNumber < 1 {
		writeError(w, http.StatusBadRequest, "短剧 ID 或集数无效")
		return
	}
	if _, found, err := s.store.GetDrama(r.Context(), input.DramaID); err != nil {
		writeError(w, http.StatusInternalServerError, "无法读取短剧")
		return
	} else if !found {
		writeError(w, http.StatusNotFound, "剧库中没有该短剧")
		return
	}
	engagement, err := s.store.PreloadEpisodeEngagement(r.Context(), input.DramaID, input.EpisodeNumber)
	if err != nil {
		if errors.Is(err, store.ErrInvalidInput) {
			writeError(w, http.StatusBadRequest, "短剧 ID 或集数无效")
			return
		}
		writeError(w, http.StatusInternalServerError, "无法读取分集互动热度")
		return
	}
	writeJSON(w, http.StatusOK, engagement)
}

func (s *Server) handleDownload(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	var input struct {
		IDs     []string `json:"ids"`
		Quality int      `json:"quality"`
	}
	if !decodeJSON(w, r, &input) {
		return
	}
	if len(input.IDs) == 0 || len(input.IDs) > 1000 || input.Quality < 0 || input.Quality > 10 {
		writeError(w, http.StatusBadRequest, "下载参数无效")
		return
	}
	tasks, err := s.store.CreateDownloadTasks(r.Context(), viewerID(w, r), input.IDs, input.Quality)
	if errors.Is(err, store.ErrNotFound) {
		writeError(w, http.StatusNotFound, "剧库中没有该剧集")
		return
	}
	if err != nil {
		writeError(w, http.StatusInternalServerError, "下载任务未保存")
		return
	}
	writeJSON(w, http.StatusAccepted, map[string]any{"data": tasks, "pending": true})
}

func (s *Server) handleRankings(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	board := r.URL.Query().Get("board")
	if board == "" {
		writeJSON(w, http.StatusOK, map[string]any{"boards": []any{}})
		return
	}
	page, err := strconv.Atoi(firstNonEmpty(r.URL.Query().Get("page"), "1"))
	if err != nil || page < 1 || page > 500 {
		writeError(w, http.StatusBadRequest, "榜单或页码无效")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"boardId": board, "page": page, "items": []any{}, "hasMore": false, "saved": true})
}

func (s *Server) handleRecommendations(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	var input struct {
		Genre     string   `json:"genre"`
		Offset    int      `json:"offset"`
		SessionID string   `json:"sessionId"`
		Seen      []string `json:"seen"`
	}
	if !decodeJSON(w, r, &input) {
		return
	}
	if input.Offset < 0 || input.Offset > 1000000 || len(input.SessionID) > 4096 || len(input.Seen) > 540 {
		writeError(w, http.StatusBadRequest, "推荐分页参数无效")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"data": []Drama{}, "nextOffset": input.Offset, "sessionId": input.SessionID, "hasMore": false, "saved": true})
}

func (s *Server) handleImage(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "method not allowed")
		return
	}
	raw := strings.TrimSpace(r.URL.Query().Get("url"))
	parsed, err := url.Parse(raw)
	if err != nil || parsed.User != nil || parsed.Host == "" || parsed.Scheme != "http" && parsed.Scheme != "https" {
		writeError(w, http.StatusBadRequest, "图片地址无效")
		return
	}
	http.Redirect(w, r, parsed.String(), http.StatusFound)
}

func viewerID(w http.ResponseWriter, r *http.Request) string {
	if cookie, err := r.Cookie(viewerCookie); err == nil && validViewerID(cookie.Value) {
		return cookie.Value
	}
	id := randomID("viewer")
	http.SetCookie(w, &http.Cookie{Name: viewerCookie, Value: id, Path: "/", HttpOnly: true, SameSite: http.SameSiteLaxMode, MaxAge: 31536000})
	return id
}

func validViewerID(value string) bool {
	return len(value) >= 16 && len(value) <= 128 && !strings.ContainsAny(value, "\r\n\x00")
}

func randomID(prefix string) string {
	buf := make([]byte, 16)
	if _, err := rand.Read(buf); err != nil {
		return fmt.Sprintf("%s-%d", prefix, time.Now().UnixNano())
	}
	return prefix + "-" + hex.EncodeToString(buf)
}

func decodeJSON(w http.ResponseWriter, r *http.Request, target any) bool {
	decoder := json.NewDecoder(http.MaxBytesReader(w, r.Body, 64<<10))
	if err := decoder.Decode(target); err != nil {
		writeError(w, http.StatusBadRequest, "请求 JSON 无效")
		return false
	}
	var extra any
	if err := decoder.Decode(&extra); err == nil {
		writeError(w, http.StatusBadRequest, "请求 JSON 只能包含一个对象")
		return false
	} else if !errors.Is(err, io.EOF) {
		writeError(w, http.StatusBadRequest, "请求 JSON 无效")
		return false
	}
	return true
}

func dramaCover(drama Drama) string {
	for _, value := range []any{drama.CoverURL, drama.CoverURLSnake, drama.Cover, drama.ImageURL, drama.ImageURLSnake, drama.Image, drama.Img, drama.Pic, drama.Picture, drama.Poster, drama.Thumb, drama.Thumbnail} {
		if text, ok := value.(string); ok && strings.TrimSpace(text) != "" {
			return strings.TrimSpace(text)
		}
	}
	return ""
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return strings.TrimSpace(value)
		}
	}
	return ""
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, map[string]string{"error": message})
}
