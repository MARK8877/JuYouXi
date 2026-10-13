package api

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"reflect"
	"strings"
	"testing"
	"time"
)

func TestLibraryRoutesExposeCompatibleShapes(t *testing.T) {
	server := NewServer(NewMemoryStore())

	health := httptest.NewRecorder()
	server.ServeHTTP(health, httptest.NewRequest(http.MethodGet, "/health", nil))
	if health.Code != http.StatusOK || !strings.Contains(health.Body.String(), `"status":"ok"`) {
		t.Fatalf("health = %d %s", health.Code, health.Body.String())
	}

	viewer := httptest.NewRecorder()
	server.ServeHTTP(viewer, httptest.NewRequest(http.MethodGet, "/api/ui/viewer", nil))
	if viewer.Code != http.StatusOK {
		t.Fatalf("viewer = %d %s", viewer.Code, viewer.Body.String())
	}
	if viewer.Result().Cookies() == nil || len(viewer.Result().Cookies()) == 0 {
		t.Fatal("viewer did not establish a viewer cookie")
	}

	dramas := httptest.NewRecorder()
	server.ServeHTTP(dramas, httptest.NewRequest(http.MethodGet, "/api/ui/dramas?revision=0", nil))
	if dramas.Code != http.StatusOK {
		t.Fatalf("dramas = %d %s", dramas.Code, dramas.Body.String())
	}
	var dramaBody struct {
		Data     []Drama `json:"data"`
		Revision uint64  `json:"revision"`
	}
	if err := json.NewDecoder(dramas.Body).Decode(&dramaBody); err != nil {
		t.Fatal(err)
	}
	if dramaBody.Data == nil {
		t.Fatal("dramas.data must be an array")
	}

	search := httptest.NewRecorder()
	server.ServeHTTP(search, httptest.NewRequest(http.MethodGet, "/api/ui/search?q=测试", nil))
	if search.Code != http.StatusOK || !strings.Contains(search.Body.String(), `"query":"测试"`) {
		t.Fatalf("search = %d %s", search.Code, search.Body.String())
	}
}

func TestFollowingRequiresAndUsesViewerCookie(t *testing.T) {
	server := NewServer(NewMemoryStore())
	request := httptest.NewRequest(http.MethodPost, "/api/ui/following", strings.NewReader(`{"dramaId":"hongguo:1","saved":true}`))
	request.Header.Set("Content-Type", "application/json")
	response := httptest.NewRecorder()
	server.ServeHTTP(response, request)
	if response.Code != http.StatusNotFound {
		t.Fatalf("unknown following = %d %s", response.Code, response.Body.String())
	}
}

func TestPlaybackHistoryRoundTripsThroughViewerCookie(t *testing.T) {
	store := NewMemoryStore()
	if err := store.UpsertDrama(context.Background(), Drama{
		ID:           "hongguo:history-1",
		Source:       "hongguo",
		Title:        "观看记录测试剧",
		Name:         "观看记录测试剧",
		CategoryName: "古装",
		TotalEpisode: 12,
	}); err != nil {
		t.Fatal(err)
	}
	server := NewServer(store)

	post := httptest.NewRequest(http.MethodPost, "/api/ui/history", strings.NewReader(`{"dramaId":"hongguo:history-1","episodeNumber":3,"positionSeconds":18,"durationSeconds":42}`))
	post.Header.Set("Content-Type", "application/json")
	posted := httptest.NewRecorder()
	server.ServeHTTP(posted, post)
	if posted.Code != http.StatusOK || !strings.Contains(posted.Body.String(), `"episodeNumber":3`) {
		t.Fatalf("post history = %d %s", posted.Code, posted.Body.String())
	}
	cookies := posted.Result().Cookies()
	if len(cookies) == 0 {
		t.Fatal("history post did not establish a viewer cookie")
	}

	get := httptest.NewRequest(http.MethodGet, "/api/ui/history", nil)
	get.AddCookie(cookies[0])
	got := httptest.NewRecorder()
	server.ServeHTTP(got, get)
	if got.Code != http.StatusOK || !strings.Contains(got.Body.String(), `"title":"观看记录测试剧"`) {
		t.Fatalf("get history = %d %s", got.Code, got.Body.String())
	}
}

func TestPlaybackHistoryRejectsInvalidEpisode(t *testing.T) {
	server := NewServer(NewMemoryStore())
	request := httptest.NewRequest(http.MethodPost, "/api/ui/history", strings.NewReader(`{"dramaId":"hongguo:missing","episodeNumber":0}`))
	request.Header.Set("Content-Type", "application/json")
	response := httptest.NewRecorder()
	server.ServeHTTP(response, request)
	if response.Code != http.StatusBadRequest {
		t.Fatalf("invalid history = %d %s", response.Code, response.Body.String())
	}
}

func TestDramaCommentsSeedOnceAndPersistViewerComment(t *testing.T) {
	database := NewMemoryStore()
	if err := database.UpsertDrama(context.Background(), Drama{
		ID:    "hongguo:comments-1",
		Title: "评论测试剧",
		Name:  "评论测试剧",
	}); err != nil {
		t.Fatal(err)
	}
	server := NewServer(database)

	read := func() *httptest.ResponseRecorder {
		response := httptest.NewRecorder()
		request := httptest.NewRequest(http.MethodGet, "/api/ui/comments?dramaId=hongguo:comments-1", nil)
		server.ServeHTTP(response, request)
		return response
	}
	first := read()
	if first.Code != http.StatusOK {
		t.Fatalf("first comments = %d %s", first.Code, first.Body.String())
	}
	var firstBody struct {
		Data  []map[string]any `json:"data"`
		Total int              `json:"total"`
	}
	if err := json.NewDecoder(first.Body).Decode(&firstBody); err != nil {
		t.Fatal(err)
	}
	if firstBody.Total != 10 || len(firstBody.Data) != 10 {
		t.Fatalf("first comments total = %d, data length = %d", firstBody.Total, len(firstBody.Data))
	}

	second := read()
	if second.Code != http.StatusOK || !strings.Contains(second.Body.String(), `"total":10`) {
		t.Fatalf("second comments = %d %s", second.Code, second.Body.String())
	}

	post := httptest.NewRequest(http.MethodPost, "/api/ui/comments", strings.NewReader(`{"dramaId":"hongguo:comments-1","content":"很好看"}`))
	post.Header.Set("Content-Type", "application/json")
	posted := httptest.NewRecorder()
	server.ServeHTTP(posted, post)
	if posted.Code != http.StatusOK || !strings.Contains(posted.Body.String(), `"content":"很好看"`) {
		t.Fatalf("post comment = %d %s", posted.Code, posted.Body.String())
	}

	last := read()
	if last.Code != http.StatusOK || !strings.Contains(last.Body.String(), `"total":11`) || !strings.Contains(last.Body.String(), `"content":"很好看"`) {
		t.Fatalf("comments after submit = %d %s", last.Code, last.Body.String())
	}
}

func TestEngagementHeatEndpointReturnsPersistentSimulatedCounts(t *testing.T) {
	database := NewMemoryStore()
	dramaID := "hongguo:engagement-api-1"
	if err := database.UpsertDrama(context.Background(), Drama{
		ID:    dramaID,
		Title: "互动热度测试剧",
		Views: "10万次播放",
	}); err != nil {
		t.Fatal(err)
	}
	now := time.Date(2026, 10, 13, 10, 0, 0, 0, time.UTC)
	if err := database.AdvanceEngagementGrowth(context.Background(), now); err != nil {
		t.Fatal(err)
	}
	server := NewServer(database)
	response := httptest.NewRecorder()
	server.ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/api/ui/engagement?dramaId="+dramaID, nil))
	if response.Code != http.StatusOK {
		t.Fatalf("engagement heat = %d %s", response.Code, response.Body.String())
	}
	var body struct {
		DramaID   string `json:"dramaId"`
		Simulated bool   `json:"simulated"`
		Likes     int64  `json:"likes"`
		Comments  int64  `json:"comments"`
		Favorites int64  `json:"favorites"`
		Shares    int64  `json:"shares"`
	}
	if err := json.NewDecoder(response.Body).Decode(&body); err != nil {
		t.Fatal(err)
	}
	if body.DramaID != dramaID || !body.Simulated || body.Likes <= 0 || body.Comments <= 0 || body.Favorites <= 0 || body.Shares <= 0 {
		t.Fatalf("engagement response = %+v", body)
	}

	comments := httptest.NewRecorder()
	server.ServeHTTP(comments, httptest.NewRequest(http.MethodGet, "/api/ui/comments?dramaId="+dramaID, nil))
	if comments.Code != http.StatusOK || !strings.Contains(comments.Body.String(), `"total":10`) {
		t.Fatalf("simulated comment heat must not create comment rows: %d %s", comments.Code, comments.Body.String())
	}
}

func TestEngagementHeatEndpointValidatesDramaID(t *testing.T) {
	server := NewServer(NewMemoryStore())
	for _, test := range []struct {
		path string
		want int
	}{
		{path: "/api/ui/engagement", want: http.StatusBadRequest},
		{path: "/api/ui/engagement?dramaId=hongguo:missing", want: http.StatusNotFound},
	} {
		response := httptest.NewRecorder()
		server.ServeHTTP(response, httptest.NewRequest(http.MethodGet, test.path, nil))
		if response.Code != test.want {
			t.Fatalf("GET %s = %d, want %d: %s", test.path, response.Code, test.want, response.Body.String())
		}
	}
}

func TestEpisodeEngagementPreloadReturnsStablePerEpisodeCounts(t *testing.T) {
	database := NewMemoryStore()
	dramaID := "hongguo:episode-engagement-api-1"
	if err := database.UpsertDrama(context.Background(), Drama{ID: dramaID, Title: "每集热度测试剧"}); err != nil {
		t.Fatal(err)
	}
	server := NewServer(database)
	preload := func(episode int) *httptest.ResponseRecorder {
		body, err := json.Marshal(map[string]any{"dramaId": dramaID, "episodeNumber": episode})
		if err != nil {
			t.Fatal(err)
		}
		request := httptest.NewRequest(http.MethodPost, "/api/ui/episode-engagement", bytes.NewReader(body))
		response := httptest.NewRecorder()
		server.ServeHTTP(response, request)
		return response
	}
	decode := func(response *httptest.ResponseRecorder) map[string]any {
		t.Helper()
		var body map[string]any
		if err := json.NewDecoder(response.Body).Decode(&body); err != nil {
			t.Fatal(err)
		}
		return body
	}

	first := preload(1)
	if first.Code != http.StatusOK {
		t.Fatalf("preload episode engagement = %d %s", first.Code, first.Body.String())
	}
	firstBody := decode(first)
	repeated := preload(1)
	if repeated.Code != http.StatusOK {
		t.Fatalf("repeat preload = %d %s", repeated.Code, repeated.Body.String())
	}
	repeatedBody := decode(repeated)
	if !reflect.DeepEqual(firstBody, repeatedBody) {
		t.Fatalf("repeat preload changed persisted values: first=%v repeated=%v", firstBody, repeatedBody)
	}
	if firstBody["episodeNumber"] != float64(1) {
		t.Fatalf("episode identity missing: %v", firstBody)
	}
	for _, field := range []string{"likes", "comments", "favorites", "shares"} {
		count, ok := firstBody[field].(float64)
		if !ok || count < 1000 || count > 9999 {
			t.Fatalf("%s = %v, want an integer in 1000..9999", field, firstBody[field])
		}
	}
	second := preload(2)
	if second.Code != http.StatusOK {
		t.Fatalf("preload second episode = %d %s", second.Code, second.Body.String())
	}
	if decode(second)["episodeNumber"] != float64(2) {
		t.Fatal("second preload returned the wrong episode")
	}
}

func TestEpisodeEngagementPreloadValidatesEpisodeAndDrama(t *testing.T) {
	server := NewServer(NewMemoryStore())
	for _, test := range []struct {
		name string
		body string
		want int
	}{
		{name: "missing drama id", body: `{"episodeNumber":1}`, want: http.StatusBadRequest},
		{name: "invalid episode number", body: `{"dramaId":"hongguo:missing","episodeNumber":0}`, want: http.StatusBadRequest},
		{name: "missing drama", body: `{"dramaId":"hongguo:missing","episodeNumber":1}`, want: http.StatusNotFound},
	} {
		t.Run(test.name, func(t *testing.T) {
			request := httptest.NewRequest(http.MethodPost, "/api/ui/episode-engagement", strings.NewReader(test.body))
			response := httptest.NewRecorder()
			server.ServeHTTP(response, request)
			if response.Code != test.want {
				t.Fatalf("preload status = %d, want %d: %s", response.Code, test.want, response.Body.String())
			}
		})
	}
}

func TestDramaCommentRepliesPersistAtOneNestedLevel(t *testing.T) {
	database := NewMemoryStore()
	for _, id := range []string{"hongguo:thread-1", "hongguo:thread-2"} {
		if err := database.UpsertDrama(context.Background(), Drama{ID: id, Title: id, Name: id}); err != nil {
			t.Fatal(err)
		}
	}
	server := NewServer(database)
	read := func(dramaID string) *httptest.ResponseRecorder {
		response := httptest.NewRecorder()
		request := httptest.NewRequest(http.MethodGet, "/api/ui/comments?dramaId="+dramaID, nil)
		server.ServeHTTP(response, request)
		return response
	}
	post := func(body string) *httptest.ResponseRecorder {
		response := httptest.NewRecorder()
		request := httptest.NewRequest(http.MethodPost, "/api/ui/comments", strings.NewReader(body))
		request.Header.Set("Content-Type", "application/json")
		server.ServeHTTP(response, request)
		return response
	}
	type comment struct {
		ID         string `json:"id"`
		ParentID   string `json:"parentId"`
		ReplyCount int    `json:"replyCount"`
	}
	type commentPage struct {
		Data  []comment `json:"data"`
		Total int       `json:"total"`
	}
	type commentSubmission struct {
		Data             comment `json:"data"`
		Total            int     `json:"total"`
		ParentReplyCount int     `json:"parentReplyCount"`
	}
	decodePage := func(t *testing.T, response *httptest.ResponseRecorder) commentPage {
		t.Helper()
		var page commentPage
		if err := json.NewDecoder(response.Body).Decode(&page); err != nil {
			t.Fatal(err)
		}
		return page
	}
	decodeSubmission := func(t *testing.T, response *httptest.ResponseRecorder) commentSubmission {
		t.Helper()
		var submission commentSubmission
		if err := json.NewDecoder(response.Body).Decode(&submission); err != nil {
			t.Fatal(err)
		}
		return submission
	}

	seeded := read("hongguo:thread-1")
	if seeded.Code != http.StatusOK {
		t.Fatalf("seeded comments = %d %s", seeded.Code, seeded.Body.String())
	}
	seedPage := decodePage(t, seeded)
	if seedPage.Total != 10 || len(seedPage.Data) != 10 {
		t.Fatalf("seed total = %d, data = %d", seedPage.Total, len(seedPage.Data))
	}
	root := seedPage.Data[0]

	createdRoot := post(`{"dramaId":"hongguo:thread-1","content":"一级评论"}`)
	if createdRoot.Code != http.StatusOK {
		t.Fatalf("create root = %d %s", createdRoot.Code, createdRoot.Body.String())
	}
	rootPage := decodeSubmission(t, createdRoot)
	if rootPage.Total != 11 || rootPage.Data.ID == "" {
		t.Fatalf("root response total = %d, data = %+v", rootPage.Total, rootPage.Data)
	}
	root = rootPage.Data

	replyResponse := post(`{"dramaId":"hongguo:thread-1","content":"二级回复","parentId":"` + root.ID + `"}`)
	if replyResponse.Code != http.StatusOK {
		t.Fatalf("create reply = %d %s", replyResponse.Code, replyResponse.Body.String())
	}
	replyPage := decodeSubmission(t, replyResponse)
	if replyPage.Total != 12 || replyPage.Data.ID == "" {
		t.Fatalf("reply response total = %d, data = %+v", replyPage.Total, replyPage.Data)
	}
	reply := replyPage.Data
	if reply.ParentID != root.ID || replyPage.ParentReplyCount != 1 {
		t.Fatalf("reply parent/count = %q/%d, want %q/1", reply.ParentID, replyPage.ParentReplyCount, root.ID)
	}

	page := decodePage(t, read("hongguo:thread-1"))
	if page.Total != 12 {
		t.Fatalf("thread total = %d, want 12", page.Total)
	}
	var foundRoot, foundReply bool
	for _, item := range page.Data {
		if item.ID == root.ID {
			foundRoot = item.ParentID == "" && item.ReplyCount == 1
		}
		if item.ID == reply.ID {
			foundReply = item.ParentID == root.ID
		}
	}
	if !foundRoot || !foundReply {
		t.Fatalf("persisted thread = %+v", page.Data)
	}

	if nested := post(`{"dramaId":"hongguo:thread-1","content":"不允许第三层","parentId":"` + reply.ID + `"}`); nested.Code != http.StatusBadRequest {
		t.Fatalf("nested reply = %d %s, want 400", nested.Code, nested.Body.String())
	}
	if crossDrama := post(`{"dramaId":"hongguo:thread-2","content":"跨剧回复","parentId":"` + root.ID + `"}`); crossDrama.Code != http.StatusBadRequest {
		t.Fatalf("cross-drama reply = %d %s, want 400", crossDrama.Code, crossDrama.Body.String())
	}
	if page := decodePage(t, read("hongguo:thread-1")); page.Total != 12 {
		t.Fatalf("invalid replies changed total to %d, want 12", page.Total)
	}
}

func TestDramaCommentsRejectInvalidRequests(t *testing.T) {
	server := NewServer(NewMemoryStore())
	for _, request := range []*http.Request{
		httptest.NewRequest(http.MethodGet, "/api/ui/comments", nil),
		httptest.NewRequest(http.MethodPost, "/api/ui/comments", strings.NewReader(`{"dramaId":"hongguo:missing","content":""}`)),
	} {
		if request.Method == http.MethodPost {
			request.Header.Set("Content-Type", "application/json")
		}
		response := httptest.NewRecorder()
		server.ServeHTTP(response, request)
		if response.Code != http.StatusBadRequest {
			t.Fatalf("%s %s = %d %s", request.Method, request.URL, response.Code, response.Body.String())
		}
	}
}

func TestSwaggerDocsAreServed(t *testing.T) {
	server := NewServerWithSpec(NewMemoryStore(), []byte("openapi: 3.0.3\n"))

	page := httptest.NewRecorder()
	server.ServeHTTP(page, httptest.NewRequest(http.MethodGet, "/swagger/", nil))
	if page.Code != http.StatusOK || !strings.Contains(page.Body.String(), "SwaggerUIBundle") {
		t.Fatalf("swagger page = %d %s", page.Code, page.Body.String())
	}

	spec := httptest.NewRecorder()
	server.ServeHTTP(spec, httptest.NewRequest(http.MethodGet, "/swagger/openapi.yaml", nil))
	if spec.Code != http.StatusOK || !strings.Contains(spec.Body.String(), "openapi: 3.0.3") {
		t.Fatalf("swagger spec = %d %s", spec.Code, spec.Body.String())
	}
}
