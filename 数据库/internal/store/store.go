package store

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	mathrand "math/rand"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
	"unicode/utf8"
)

var ErrNotFound = errors.New("not found")
var ErrInvalidInput = errors.New("invalid input")

type Drama struct {
	VIP               *bool         `json:"vip,omitempty"`
	ID                string        `json:"id"`
	Source            string        `json:"source,omitempty"`
	SourceID          string        `json:"sourceId,omitempty"`
	Title             string        `json:"title"`
	Name              string        `json:"name"`
	Desc              string        `json:"desc"`
	Intro             string        `json:"intro"`
	Cover             any           `json:"cover"`
	CoverURL          any           `json:"coverUrl"`
	CoverURLSnake     any           `json:"cover_url"`
	Image             any           `json:"image"`
	ImageURL          any           `json:"imageUrl"`
	ImageURLSnake     any           `json:"image_url"`
	Img               any           `json:"img"`
	Pic               any           `json:"pic"`
	Picture           any           `json:"picture"`
	Poster            any           `json:"poster"`
	Thumb             any           `json:"thumb"`
	Thumbnail         any           `json:"thumbnail"`
	TotalEpisode      any           `json:"totalEpisode"`
	TotalEpisodeSnake any           `json:"total_episode"`
	ChapterCount      any           `json:"chapterCount"`
	ChapterCountSnake any           `json:"chapter_count"`
	EpisodeCount      any           `json:"episodeCount"`
	EpisodeCountSnake any           `json:"episode_count"`
	Total             any           `json:"total"`
	Episodes          any           `json:"episodes"`
	Duration          any           `json:"duration"`
	ChannelName       string        `json:"channelName"`
	Category          string        `json:"category"`
	CategoryName      string        `json:"categoryName"`
	CategoryNameSnake string        `json:"category_name"`
	TypeName          string        `json:"typeName"`
	TypeNameSnake     string        `json:"type_name"`
	SortName          string        `json:"sortName"`
	SortNameSnake     string        `json:"sort_name"`
	Remark            string        `json:"remark,omitempty"`
	Score             string        `json:"score,omitempty"`
	Views             string        `json:"views,omitempty"`
	Heat              string        `json:"heat,omitempty"`
	OnlineDate        string        `json:"onlineDate,omitempty"`
	Tags              []string      `json:"tags,omitempty"`
	ReleaseStatus     string        `json:"releaseStatus,omitempty"`
	SortMetadata      *SortMetadata `json:"sortMetadata,omitempty"`
}

type SortMetadata struct {
	Version      int       `json:"version"`
	CheckedAt    time.Time `json:"checkedAt"`
	Pending      bool      `json:"pending,omitempty"`
	CoverChecked bool      `json:"coverChecked,omitempty"`
}

type DramaFilter struct {
	Source string
	Search string
}

type LibrarySource struct {
	Status    string    `json:"status"`
	Count     int       `json:"count"`
	Error     string    `json:"error,omitempty"`
	UpdatedAt time.Time `json:"updatedAt"`
	Revision  uint64    `json:"-"`
}

type Following struct {
	DramaID       string    `json:"dramaId"`
	Source        string    `json:"source"`
	Title         string    `json:"title"`
	Category      string    `json:"category,omitempty"`
	Saved         bool      `json:"saved"`
	Completed     bool      `json:"completed"`
	KnownEpisodes int       `json:"knownEpisodes"`
	AddedAt       time.Time `json:"addedAt"`
	UpdatedAt     time.Time `json:"updatedAt"`
}

type FollowInput struct {
	DramaID     string
	Saved       *bool
	Completed   *bool
	Acknowledge bool
}

type PlaybackHistory struct {
	DramaID         string    `json:"dramaId"`
	Source          string    `json:"source"`
	Title           string    `json:"title"`
	Category        string    `json:"category,omitempty"`
	EpisodeNumber   int       `json:"episodeNumber"`
	PositionSeconds int       `json:"positionSeconds"`
	DurationSeconds int       `json:"durationSeconds"`
	WatchedAt       time.Time `json:"watchedAt"`
}

type PlaybackHistoryInput struct {
	DramaID         string
	EpisodeNumber   int
	PositionSeconds int
	DurationSeconds int
}

type DramaComment struct {
	ID         string    `json:"id"`
	DramaID    string    `json:"dramaId"`
	ParentID   string    `json:"parentId,omitempty"`
	AuthorName string    `json:"authorName"`
	Content    string    `json:"content"`
	LikeCount  int       `json:"likeCount"`
	ReplyCount int       `json:"replyCount"`
	CreatedAt  time.Time `json:"createdAt"`
	IsSeed     bool      `json:"isSeed"`
	SeedIndex  int       `json:"seedIndex,omitempty"`
}

type DramaCommentInput struct {
	DramaID  string
	Content  string
	ParentID string
}

type DownloadTask struct {
	ID        string    `json:"id"`
	DramaID   string    `json:"dramaId"`
	Title     string    `json:"title"`
	Quality   int       `json:"quality,omitempty"`
	Status    string    `json:"status"`
	Progress  int       `json:"progress"`
	CreatedAt time.Time `json:"createdAt"`
	UpdatedAt time.Time `json:"updatedAt"`
}

type Store interface {
	TouchViewer(context.Context, string) error
	ListDramas(context.Context, DramaFilter) ([]Drama, error)
	GetDrama(context.Context, string) (Drama, bool, error)
	UpsertDrama(context.Context, Drama) error
	Sources(context.Context) (map[string]LibrarySource, uint64, error)
	ListFollowing(context.Context, string) ([]Following, error)
	UpdateFollowing(context.Context, string, FollowInput) (Following, error)
	ListPlaybackHistory(context.Context, string) ([]PlaybackHistory, error)
	RecordPlaybackHistory(context.Context, string, PlaybackHistoryInput) (PlaybackHistory, error)
	GetEngagementHeat(context.Context, string) (EngagementHeat, error)
	PreloadEpisodeEngagement(context.Context, string, int) (EpisodeEngagement, error)
	AdvanceEngagementGrowth(context.Context, time.Time) error
	ListComments(context.Context, string) ([]DramaComment, error)
	CreateComment(context.Context, string, DramaCommentInput) (DramaComment, error)
	CreateDownloadTasks(context.Context, string, []string, int) ([]DownloadTask, error)
}

type Memory struct {
	mu                sync.RWMutex
	dramas            map[string]Drama
	follow            map[string]map[string]Following
	history           map[string]map[string]PlaybackHistory
	engagement        map[string]EngagementHeat
	episodeEngagement map[string]EpisodeEngagement
	comments          map[string][]DramaComment
	tasks             map[string]DownloadTask
	revision          uint64
}

func NewMemory() *Memory {
	return &Memory{dramas: map[string]Drama{}, follow: map[string]map[string]Following{}, history: map[string]map[string]PlaybackHistory{}, engagement: map[string]EngagementHeat{}, episodeEngagement: map[string]EpisodeEngagement{}, comments: map[string][]DramaComment{}, tasks: map[string]DownloadTask{}, revision: 1}
}

func (m *Memory) TouchViewer(_ context.Context, _ string) error { return nil }

func (m *Memory) ListDramas(_ context.Context, filter DramaFilter) ([]Drama, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	result := make([]Drama, 0, len(m.dramas))
	search := strings.ToLower(strings.TrimSpace(filter.Search))
	for _, drama := range m.dramas {
		if filter.Source != "" && drama.Source != filter.Source {
			continue
		}
		if search != "" && !strings.Contains(strings.ToLower(strings.Join([]string{drama.Title, drama.Name, drama.Desc, drama.Intro, drama.CategoryName}, " ")), search) {
			continue
		}
		result = append(result, drama)
	}
	sort.SliceStable(result, func(i, j int) bool { return result[i].Title < result[j].Title })
	return result, nil
}

func (m *Memory) GetDrama(_ context.Context, id string) (Drama, bool, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	drama, ok := m.dramas[id]
	return drama, ok, nil
}

func (m *Memory) UpsertDrama(_ context.Context, drama Drama) error {
	if strings.TrimSpace(drama.ID) == "" {
		return errors.New("drama id is required")
	}
	if drama.Source == "" {
		drama.Source = "hongguo"
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	m.dramas[drama.ID] = drama
	m.revision++
	return nil
}

func (m *Memory) Sources(_ context.Context) (map[string]LibrarySource, uint64, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	count := 0
	for _, drama := range m.dramas {
		if drama.Source == "hongguo" || drama.Source == "" {
			count++
		}
	}
	return map[string]LibrarySource{"hongguo": {Status: "ready", Count: count, UpdatedAt: time.Now().UTC()}}, m.revision, nil
}

func (m *Memory) ListFollowing(_ context.Context, viewerID string) ([]Following, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	entries := make([]Following, 0, len(m.follow[viewerID]))
	for _, entry := range m.follow[viewerID] {
		entries = append(entries, entry)
	}
	sort.SliceStable(entries, func(i, j int) bool { return entries[i].UpdatedAt.After(entries[j].UpdatedAt) })
	return entries, nil
}

func (m *Memory) UpdateFollowing(_ context.Context, viewerID string, input FollowInput) (Following, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	drama, ok := m.dramas[input.DramaID]
	if !ok {
		return Following{}, ErrNotFound
	}
	if m.follow[viewerID] == nil {
		m.follow[viewerID] = map[string]Following{}
	}
	entry, exists := m.follow[viewerID][input.DramaID]
	now := time.Now().UTC()
	if !exists {
		entry = Following{DramaID: drama.ID, Source: firstNonEmpty(drama.Source, "hongguo"), Title: firstNonEmpty(drama.Title, drama.Name), Category: firstNonEmpty(drama.CategoryName, drama.Category), AddedAt: now}
	}
	if input.Saved != nil {
		entry.Saved = *input.Saved
	}
	if input.Completed != nil {
		entry.Completed = *input.Completed
	}
	if input.Acknowledge || entry.KnownEpisodes == 0 {
		entry.KnownEpisodes = episodeCount(drama)
	}
	entry.UpdatedAt = now
	m.follow[viewerID][input.DramaID] = entry
	return entry, nil
}

func (m *Memory) ListPlaybackHistory(_ context.Context, viewerID string) ([]PlaybackHistory, error) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	entries := make([]PlaybackHistory, 0, len(m.history[viewerID]))
	for _, entry := range m.history[viewerID] {
		entries = append(entries, entry)
	}
	sort.SliceStable(entries, func(i, j int) bool {
		return entries[i].WatchedAt.After(entries[j].WatchedAt)
	})
	return entries, nil
}

func (m *Memory) RecordPlaybackHistory(_ context.Context, viewerID string, input PlaybackHistoryInput) (PlaybackHistory, error) {
	if err := validatePlaybackHistoryInput(input); err != nil {
		return PlaybackHistory{}, err
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	drama, ok := m.dramas[input.DramaID]
	if !ok {
		return PlaybackHistory{}, ErrNotFound
	}
	if m.history[viewerID] == nil {
		m.history[viewerID] = map[string]PlaybackHistory{}
	}
	entry := PlaybackHistory{
		DramaID:         drama.ID,
		Source:          firstNonEmpty(drama.Source, "hongguo"),
		Title:           firstNonEmpty(drama.Title, drama.Name),
		Category:        firstNonEmpty(drama.CategoryName, drama.Category, drama.TypeName),
		EpisodeNumber:   input.EpisodeNumber,
		PositionSeconds: input.PositionSeconds,
		DurationSeconds: input.DurationSeconds,
		WatchedAt:       time.Now().UTC(),
	}
	m.history[viewerID][drama.ID] = entry
	return entry, nil
}

func (m *Memory) ListComments(_ context.Context, dramaID string) ([]DramaComment, error) {
	if strings.TrimSpace(dramaID) == "" {
		return nil, ErrInvalidInput
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	if _, ok := m.dramas[dramaID]; !ok {
		return nil, ErrNotFound
	}
	if len(m.comments[dramaID]) == 0 {
		m.comments[dramaID] = newSeedComments(dramaID)
	}
	return append([]DramaComment(nil), m.comments[dramaID]...), nil
}

func (m *Memory) CreateComment(_ context.Context, _ string, input DramaCommentInput) (DramaComment, error) {
	if err := validateDramaCommentInput(input); err != nil {
		return DramaComment{}, err
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	if _, ok := m.dramas[input.DramaID]; !ok {
		return DramaComment{}, ErrNotFound
	}
	if input.ParentID != "" {
		found := false
		for index, parent := range m.comments[input.DramaID] {
			if parent.ID != input.ParentID {
				continue
			}
			if parent.ParentID != "" {
				return DramaComment{}, ErrInvalidInput
			}
			parent.ReplyCount++
			m.comments[input.DramaID][index] = parent
			found = true
			break
		}
		if !found {
			return DramaComment{}, ErrInvalidInput
		}
	}
	comment := DramaComment{
		ID:         randomID("comment"),
		DramaID:    input.DramaID,
		ParentID:   input.ParentID,
		AuthorName: "游客",
		Content:    strings.TrimSpace(input.Content),
		CreatedAt:  time.Now().UTC(),
	}
	m.comments[input.DramaID] = append(m.comments[input.DramaID], comment)
	return comment, nil
}

func (m *Memory) CreateDownloadTasks(_ context.Context, viewerID string, ids []string, quality int) ([]DownloadTask, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	result := make([]DownloadTask, 0, len(ids))
	for _, id := range ids {
		drama, ok := m.dramas[id]
		if !ok {
			return nil, ErrNotFound
		}
		now := time.Now().UTC()
		task := DownloadTask{ID: randomID("task"), DramaID: id, Title: firstNonEmpty(drama.Title, drama.Name), Quality: quality, Status: "queued", CreatedAt: now, UpdatedAt: now}
		m.tasks[task.ID+":"+viewerID] = task
		result = append(result, task)
	}
	return result, nil
}

type MySQL struct{ db *sql.DB }

func NewMySQL(db *sql.DB) *MySQL { return &MySQL{db: db} }

func (s *MySQL) TouchViewer(ctx context.Context, id string) error {
	_, err := s.db.ExecContext(ctx, `INSERT INTO viewers (id) VALUES (?) ON DUPLICATE KEY UPDATE updated_at=UTC_TIMESTAMP()`, id)
	return err
}

func (s *MySQL) ListDramas(ctx context.Context, filter DramaFilter) ([]Drama, error) {
	query := `SELECT payload FROM dramas WHERE source = ?`
	args := []any{firstNonEmpty(filter.Source, "hongguo")}
	if strings.TrimSpace(filter.Search) != "" {
		query += ` AND (title LIKE ? OR name LIKE ? OR description LIKE ? OR intro LIKE ? OR category_name LIKE ? OR tags_text LIKE ?)`
		needle := "%" + strings.TrimSpace(filter.Search) + "%"
		args = append(args, needle, needle, needle, needle, needle, needle)
	}
	query += ` ORDER BY title ASC, id ASC`
	rows, err := s.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := make([]Drama, 0)
	for rows.Next() {
		var payload []byte
		if err := rows.Scan(&payload); err != nil {
			return nil, err
		}
		var drama Drama
		if err := json.Unmarshal(payload, &drama); err != nil {
			return nil, fmt.Errorf("decode drama payload: %w", err)
		}
		result = append(result, drama)
	}
	return result, rows.Err()
}

func (s *MySQL) GetDrama(ctx context.Context, id string) (Drama, bool, error) {
	var payload []byte
	err := s.db.QueryRowContext(ctx, `SELECT payload FROM dramas WHERE id = ?`, id).Scan(&payload)
	if errors.Is(err, sql.ErrNoRows) {
		return Drama{}, false, nil
	}
	if err != nil {
		return Drama{}, false, err
	}
	var drama Drama
	if err := json.Unmarshal(payload, &drama); err != nil {
		return Drama{}, false, fmt.Errorf("decode drama payload: %w", err)
	}
	return drama, true, nil
}

func (s *MySQL) UpsertDrama(ctx context.Context, drama Drama) error {
	if strings.TrimSpace(drama.ID) == "" {
		return errors.New("drama id is required")
	}
	if drama.Source == "" {
		drama.Source = "hongguo"
	}
	if drama.SourceID == "" {
		drama.SourceID = strings.TrimPrefix(drama.ID, drama.Source+":")
	}
	payload, err := json.Marshal(drama)
	if err != nil {
		return err
	}
	_, err = s.db.ExecContext(ctx, `
		INSERT INTO dramas (id, source, source_id, title, name, description, intro, category_name, tags_text, total_episode, release_status, payload)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE source=?, source_id=?, title=?, name=?, description=?, intro=?, category_name=?, tags_text=?, total_episode=?, release_status=?, payload=?, updated_at=UTC_TIMESTAMP()`,
		drama.ID, drama.Source, drama.SourceID, drama.Title, drama.Name, drama.Desc, drama.Intro, firstNonEmpty(drama.CategoryName, drama.CategoryNameSnake, drama.Category), strings.Join(drama.Tags, " "), episodeCount(drama), drama.ReleaseStatus, payload,
		drama.Source, drama.SourceID, drama.Title, drama.Name, drama.Desc, drama.Intro, firstNonEmpty(drama.CategoryName, drama.CategoryNameSnake, drama.Category), strings.Join(drama.Tags, " "), episodeCount(drama), drama.ReleaseStatus, payload)
	if err != nil {
		return err
	}
	return s.refreshSource(ctx, drama.Source)
}

func (s *MySQL) refreshSource(ctx context.Context, source string) error {
	var count int
	if err := s.db.QueryRowContext(ctx, `SELECT COUNT(*) FROM dramas WHERE source = ?`, source).Scan(&count); err != nil {
		return err
	}
	_, err := s.db.ExecContext(ctx, `
		INSERT INTO library_sources (source, status, count, updated_at, revision)
		VALUES (?, 'ready', ?, UTC_TIMESTAMP(), 1)
		ON DUPLICATE KEY UPDATE status='ready', count=?, updated_at=UTC_TIMESTAMP(), revision=revision+1`, source, count, count)
	return err
}

func (s *MySQL) Sources(ctx context.Context) (map[string]LibrarySource, uint64, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT source, status, count, error_message, updated_at, revision FROM library_sources`)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()
	result := map[string]LibrarySource{}
	var revision uint64
	for rows.Next() {
		var source, status string
		var count int
		var message sql.NullString
		var updated time.Time
		var current uint64
		if err := rows.Scan(&source, &status, &count, &message, &updated, &current); err != nil {
			return nil, 0, err
		}
		result[source] = LibrarySource{Status: status, Count: count, Error: message.String, UpdatedAt: updated, Revision: current}
		if current > revision {
			revision = current
		}
	}
	if len(result) == 0 {
		result["hongguo"] = LibrarySource{Status: "ready", UpdatedAt: time.Now().UTC()}
	}
	return result, revision, rows.Err()
}

func (s *MySQL) ListFollowing(ctx context.Context, viewerID string) ([]Following, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT drama_id, source, title, category, saved, completed, known_episodes, added_at, updated_at FROM following WHERE viewer_id=? ORDER BY updated_at DESC`, viewerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := make([]Following, 0)
	for rows.Next() {
		var entry Following
		if err := rows.Scan(&entry.DramaID, &entry.Source, &entry.Title, &entry.Category, &entry.Saved, &entry.Completed, &entry.KnownEpisodes, &entry.AddedAt, &entry.UpdatedAt); err != nil {
			return nil, err
		}
		result = append(result, entry)
	}
	return result, rows.Err()
}

func (s *MySQL) UpdateFollowing(ctx context.Context, viewerID string, input FollowInput) (Following, error) {
	drama, found, err := s.GetDrama(ctx, input.DramaID)
	if err != nil {
		return Following{}, err
	}
	if !found {
		return Following{}, ErrNotFound
	}
	entry := Following{DramaID: drama.ID, Source: firstNonEmpty(drama.Source, "hongguo"), Title: firstNonEmpty(drama.Title, drama.Name), Category: firstNonEmpty(drama.CategoryName, drama.Category), KnownEpisodes: episodeCount(drama)}
	var existing Following
	row := s.db.QueryRowContext(ctx, `SELECT drama_id, source, title, category, saved, completed, known_episodes, added_at, updated_at FROM following WHERE viewer_id=? AND drama_id=?`, viewerID, input.DramaID)
	if scanErr := row.Scan(&existing.DramaID, &existing.Source, &existing.Title, &existing.Category, &existing.Saved, &existing.Completed, &existing.KnownEpisodes, &existing.AddedAt, &existing.UpdatedAt); scanErr == nil {
		entry = existing
		entry.Title, entry.Category = firstNonEmpty(drama.Title, drama.Name), firstNonEmpty(drama.CategoryName, drama.Category)
		if entry.KnownEpisodes == 0 || input.Acknowledge {
			entry.KnownEpisodes = episodeCount(drama)
		}
	} else if !errors.Is(scanErr, sql.ErrNoRows) {
		return Following{}, scanErr
	} else {
		entry.AddedAt = time.Now().UTC()
	}
	if input.Saved != nil {
		entry.Saved = *input.Saved
	}
	if input.Completed != nil {
		entry.Completed = *input.Completed
	}
	entry.UpdatedAt = time.Now().UTC()
	_, err = s.db.ExecContext(ctx, `
		INSERT INTO following (viewer_id, drama_id, source, title, category, saved, completed, known_episodes, added_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE source=?, title=?, category=?, saved=?, completed=?, known_episodes=?, updated_at=?`,
		viewerID, entry.DramaID, entry.Source, entry.Title, entry.Category, entry.Saved, entry.Completed, entry.KnownEpisodes, entry.AddedAt, entry.UpdatedAt,
		entry.Source, entry.Title, entry.Category, entry.Saved, entry.Completed, entry.KnownEpisodes, entry.UpdatedAt)
	return entry, err
}

func (s *MySQL) ListPlaybackHistory(ctx context.Context, viewerID string) ([]PlaybackHistory, error) {
	rows, err := s.db.QueryContext(ctx, `SELECT drama_id, payload, watched_at FROM playback_history WHERE viewer_id=? ORDER BY watched_at DESC`, viewerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	result := make([]PlaybackHistory, 0)
	for rows.Next() {
		var dramaID string
		var payload []byte
		var watchedAt time.Time
		if err := rows.Scan(&dramaID, &payload, &watchedAt); err != nil {
			return nil, err
		}
		var entry PlaybackHistory
		if err := json.Unmarshal(payload, &entry); err != nil {
			return nil, fmt.Errorf("decode playback history payload: %w", err)
		}
		entry.DramaID = firstNonEmpty(entry.DramaID, dramaID)
		entry.WatchedAt = watchedAt
		result = append(result, entry)
	}
	return result, rows.Err()
}

func (s *MySQL) RecordPlaybackHistory(ctx context.Context, viewerID string, input PlaybackHistoryInput) (PlaybackHistory, error) {
	if err := validatePlaybackHistoryInput(input); err != nil {
		return PlaybackHistory{}, err
	}
	drama, found, err := s.GetDrama(ctx, input.DramaID)
	if err != nil {
		return PlaybackHistory{}, err
	}
	if !found {
		return PlaybackHistory{}, ErrNotFound
	}
	entry := PlaybackHistory{
		DramaID:         drama.ID,
		Source:          firstNonEmpty(drama.Source, "hongguo"),
		Title:           firstNonEmpty(drama.Title, drama.Name),
		Category:        firstNonEmpty(drama.CategoryName, drama.Category, drama.TypeName),
		EpisodeNumber:   input.EpisodeNumber,
		PositionSeconds: input.PositionSeconds,
		DurationSeconds: input.DurationSeconds,
		WatchedAt:       time.Now().UTC(),
	}
	payload, err := json.Marshal(entry)
	if err != nil {
		return PlaybackHistory{}, err
	}
	_, err = s.db.ExecContext(ctx, `
		INSERT INTO playback_history (viewer_id, drama_id, payload, watched_at)
		VALUES (?, ?, ?, ?)
		ON DUPLICATE KEY UPDATE payload=?, watched_at=?`,
		viewerID, entry.DramaID, payload, entry.WatchedAt, payload, entry.WatchedAt)
	return entry, err
}

func (s *MySQL) ListComments(ctx context.Context, dramaID string) ([]DramaComment, error) {
	if strings.TrimSpace(dramaID) == "" {
		return nil, ErrInvalidInput
	}
	if _, found, err := s.GetDrama(ctx, dramaID); err != nil {
		return nil, err
	} else if !found {
		return nil, ErrNotFound
	}
	transaction, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer transaction.Rollback()
	var count int
	if err := transaction.QueryRowContext(ctx, `SELECT COUNT(*) FROM drama_comments WHERE drama_id=?`, dramaID).Scan(&count); err != nil {
		return nil, err
	}
	if count == 0 {
		for _, comment := range newSeedComments(dramaID) {
			if _, err := transaction.ExecContext(ctx, `
				INSERT IGNORE INTO drama_comments
				(id, drama_id, seed_index, author_name, content, like_count, reply_count, is_seed, created_at)
				VALUES (?, ?, ?, ?, ?, ?, ?, TRUE, ?)`,
				comment.ID, comment.DramaID, comment.SeedIndex, comment.AuthorName, comment.Content,
				comment.LikeCount, comment.ReplyCount, comment.CreatedAt); err != nil {
				return nil, err
			}
		}
	}
	if err := transaction.Commit(); err != nil {
		return nil, err
	}
	rows, err := s.db.QueryContext(ctx, `
		SELECT id, drama_id, COALESCE(parent_id, ''), author_name, content, like_count, reply_count, created_at, is_seed, COALESCE(seed_index, 0)
		FROM drama_comments WHERE drama_id=? ORDER BY created_at DESC, id DESC`, dramaID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	comments := make([]DramaComment, 0)
	for rows.Next() {
		var comment DramaComment
		if err := rows.Scan(&comment.ID, &comment.DramaID, &comment.ParentID, &comment.AuthorName, &comment.Content,
			&comment.LikeCount, &comment.ReplyCount, &comment.CreatedAt, &comment.IsSeed, &comment.SeedIndex); err != nil {
			return nil, err
		}
		comments = append(comments, comment)
	}
	return comments, rows.Err()
}

func (s *MySQL) CreateComment(ctx context.Context, viewerID string, input DramaCommentInput) (DramaComment, error) {
	if err := validateDramaCommentInput(input); err != nil {
		return DramaComment{}, err
	}
	if _, found, err := s.GetDrama(ctx, input.DramaID); err != nil {
		return DramaComment{}, err
	} else if !found {
		return DramaComment{}, ErrNotFound
	}
	transaction, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return DramaComment{}, err
	}
	defer transaction.Rollback()
	if input.ParentID != "" {
		var parentDramaID, parentID string
		err := transaction.QueryRowContext(ctx, `
			SELECT drama_id, COALESCE(parent_id, '') FROM drama_comments WHERE id=? FOR UPDATE`,
			input.ParentID).Scan(&parentDramaID, &parentID)
		if errors.Is(err, sql.ErrNoRows) {
			return DramaComment{}, ErrInvalidInput
		}
		if err != nil {
			return DramaComment{}, err
		}
		if parentDramaID != input.DramaID || parentID != "" {
			return DramaComment{}, ErrInvalidInput
		}
		if _, err := transaction.ExecContext(ctx,
			`UPDATE drama_comments SET reply_count=reply_count+1 WHERE id=? AND drama_id=?`,
			input.ParentID, input.DramaID); err != nil {
			return DramaComment{}, err
		}
	}
	comment := DramaComment{
		ID:         randomID("comment"),
		DramaID:    input.DramaID,
		ParentID:   input.ParentID,
		AuthorName: "游客",
		Content:    strings.TrimSpace(input.Content),
		CreatedAt:  time.Now().UTC(),
	}
	var parentID any
	if input.ParentID != "" {
		parentID = input.ParentID
	}
	if _, err := transaction.ExecContext(ctx, `
		INSERT INTO drama_comments (id, drama_id, parent_id, viewer_id, author_name, content, like_count, reply_count, is_seed, created_at)
		VALUES (?, ?, ?, ?, ?, ?, 0, 0, FALSE, ?)`,
		comment.ID, comment.DramaID, parentID, viewerID, comment.AuthorName, comment.Content, comment.CreatedAt); err != nil {
		return DramaComment{}, err
	}
	if err := transaction.Commit(); err != nil {
		return DramaComment{}, err
	}
	return comment, nil
}

func (s *MySQL) CreateDownloadTasks(ctx context.Context, viewerID string, ids []string, quality int) ([]DownloadTask, error) {
	transaction, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, err
	}
	defer transaction.Rollback()
	result := make([]DownloadTask, 0, len(ids))
	for _, id := range ids {
		var title string
		if err := transaction.QueryRowContext(ctx, `SELECT title FROM dramas WHERE id=?`, id).Scan(&title); errors.Is(err, sql.ErrNoRows) {
			return nil, ErrNotFound
		} else if err != nil {
			return nil, err
		}
		now := time.Now().UTC()
		task := DownloadTask{ID: randomID("task"), DramaID: id, Title: title, Quality: quality, Status: "queued", CreatedAt: now, UpdatedAt: now}
		if _, err := transaction.ExecContext(ctx, `INSERT INTO download_tasks (id, viewer_id, drama_id, title, quality, status, progress, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, 0, ?, ?)`, task.ID, viewerID, task.DramaID, task.Title, task.Quality, task.Status, task.CreatedAt, task.UpdatedAt); err != nil {
			return nil, err
		}
		result = append(result, task)
	}
	if err := transaction.Commit(); err != nil {
		return nil, err
	}
	return result, nil
}

func episodeCount(drama Drama) int {
	for _, value := range []any{drama.TotalEpisode, drama.TotalEpisodeSnake, drama.ChapterCount, drama.ChapterCountSnake, drama.EpisodeCount, drama.EpisodeCountSnake, drama.Total, drama.Episodes} {
		if number, err := strconv.Atoi(strings.TrimSpace(fmt.Sprint(value))); err == nil && number > 0 && number <= 10000 {
			return number
		}
	}
	return 0
}

func validatePlaybackHistoryInput(input PlaybackHistoryInput) error {
	if strings.TrimSpace(input.DramaID) == "" || input.EpisodeNumber < 1 || input.EpisodeNumber > 10000 || input.PositionSeconds < 0 || input.DurationSeconds < 0 {
		return ErrInvalidInput
	}
	return nil
}

func validateDramaCommentInput(input DramaCommentInput) error {
	content := strings.TrimSpace(input.Content)
	if strings.TrimSpace(input.DramaID) == "" || content == "" || utf8.RuneCountInString(content) > 500 {
		return ErrInvalidInput
	}
	return nil
}

func newSeedComments(dramaID string) []DramaComment {
	seedContent := []struct {
		author  string
		content string
	}{
		{"追剧小鱼", "开头节奏好快，一下子就看进去了。"},
		{"橘子汽水", "男女主演得很自然，期待后面的反转。"},
		{"晚风", "本来只想看一集，结果停不下来。"},
		{"小月亮", "服化道挺用心的，画面也很舒服。"},
		{"山茶花", "这段情绪拉满了，已经开始追更。"},
		{"看剧的人", "剧情不拖沓，适合下班放松看。"},
		{"云朵", "希望后面保持这个节奏，先收藏了。"},
		{"星星糖", "配角也很出彩，几个人的互动好有趣。"},
		{"小满", "这个设定有点意思，想知道接下来会怎样。"},
		{"一颗葡萄", "最近难得看到这么轻松的短剧。"},
		{"北岛", "转场和配乐不错，氛围一下就出来了。"},
		{"奶盖", "看到这里终于反击了，好爽！"},
		{"木木", "演员的眼神戏不错，细节有照顾到。"},
		{"纸飞机", "先点个赞，等更新的时候再回来。"},
		{"青柠", "故事挺有代入感，希望结局圆满。"},
	}
	selection := mathrand.Perm(len(seedContent))[:10]
	now := time.Now().UTC()
	comments := make([]DramaComment, 0, len(selection))
	for index, selected := range selection {
		seed := seedContent[selected]
		comments = append(comments, DramaComment{
			ID:         randomID("seed"),
			DramaID:    dramaID,
			AuthorName: seed.author,
			Content:    seed.content,
			LikeCount:  mathrand.Intn(28),
			CreatedAt:  now.Add(-time.Duration(index*7+mathrand.Intn(6)) * time.Minute),
			IsSeed:     true,
			SeedIndex:  index + 1,
		})
	}
	return comments
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if strings.TrimSpace(value) != "" {
			return strings.TrimSpace(value)
		}
	}
	return ""
}

func randomID(prefix string) string {
	buf := make([]byte, 12)
	if _, err := rand.Read(buf); err != nil {
		return fmt.Sprintf("%s-%d", prefix, time.Now().UnixNano())
	}
	return prefix + "-" + hex.EncodeToString(buf)
}
