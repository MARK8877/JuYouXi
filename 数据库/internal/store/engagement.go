package store

import (
	"context"
	"database/sql"
	"errors"
	"math"
	"math/rand"
	"strconv"
	"strings"
	"time"
)

const engagementGrowthInterval = 10 * time.Minute
const (
	minimumEpisodeEngagement = int64(1000)
	maximumEpisodeEngagement = int64(9999)
)

type EngagementHeat struct {
	DramaID      string    `json:"dramaId"`
	Likes        int64     `json:"likes"`
	Comments     int64     `json:"comments"`
	Favorites    int64     `json:"favorites"`
	Shares       int64     `json:"shares"`
	NextGrowthAt time.Time `json:"-"`
	UpdatedAt    time.Time `json:"updatedAt,omitempty"`
}

type EpisodeEngagement struct {
	DramaID       string    `json:"dramaId"`
	EpisodeNumber int       `json:"episodeNumber"`
	Likes         int64     `json:"likes"`
	Comments      int64     `json:"comments"`
	Favorites     int64     `json:"favorites"`
	Shares        int64     `json:"shares"`
	NextGrowthAt  time.Time `json:"-"`
	UpdatedAt     time.Time `json:"updatedAt,omitempty"`
}

type engagementTarget struct {
	likes     int64
	comments  int64
	favorites int64
	shares    int64
}

func (m *Memory) GetEngagementHeat(_ context.Context, dramaID string) (EngagementHeat, error) {
	if strings.TrimSpace(dramaID) == "" {
		return EngagementHeat{}, ErrInvalidInput
	}
	m.mu.RLock()
	defer m.mu.RUnlock()
	if _, ok := m.dramas[dramaID]; !ok {
		return EngagementHeat{}, ErrNotFound
	}
	heat := m.engagement[dramaID]
	heat.DramaID = dramaID
	return heat, nil
}

func (m *Memory) AdvanceEngagementGrowth(ctx context.Context, now time.Time) error {
	if err := ctx.Err(); err != nil {
		return err
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	for id, drama := range m.dramas {
		if drama.Source != "" && drama.Source != "hongguo" {
			continue
		}
		heat := m.engagement[id]
		if !heat.NextGrowthAt.IsZero() && now.Before(heat.NextGrowthAt) {
			continue
		}
		m.engagement[id] = advanceEngagementHeat(id, heat, engagementTargets(drama), now)
	}
	for key, heat := range m.episodeEngagement {
		if !heat.NextGrowthAt.IsZero() && now.Before(heat.NextGrowthAt) {
			continue
		}
		m.episodeEngagement[key] = advanceEpisodeEngagement(heat, now)
	}
	return nil
}

func (m *Memory) PreloadEpisodeEngagement(ctx context.Context, dramaID string, episodeNumber int) (EpisodeEngagement, error) {
	if err := ctx.Err(); err != nil {
		return EpisodeEngagement{}, err
	}
	if strings.TrimSpace(dramaID) == "" || episodeNumber < 1 {
		return EpisodeEngagement{}, ErrInvalidInput
	}
	m.mu.Lock()
	defer m.mu.Unlock()
	if _, ok := m.dramas[dramaID]; !ok {
		return EpisodeEngagement{}, ErrNotFound
	}
	key := episodeEngagementKey(dramaID, episodeNumber)
	if heat, ok := m.episodeEngagement[key]; ok {
		return heat, nil
	}
	heat := newEpisodeEngagement(dramaID, episodeNumber, time.Now().UTC())
	m.episodeEngagement[key] = heat
	return heat, nil
}

func (s *MySQL) GetEngagementHeat(ctx context.Context, dramaID string) (EngagementHeat, error) {
	if strings.TrimSpace(dramaID) == "" {
		return EngagementHeat{}, ErrInvalidInput
	}
	heat := EngagementHeat{DramaID: dramaID}
	err := s.db.QueryRowContext(ctx, `
		SELECT likes, comments, favorites, shares, next_growth_at, updated_at
		FROM drama_engagement_heat WHERE drama_id=?`, dramaID).Scan(
		&heat.Likes, &heat.Comments, &heat.Favorites, &heat.Shares,
		&heat.NextGrowthAt, &heat.UpdatedAt,
	)
	if errors.Is(err, sql.ErrNoRows) {
		return heat, nil
	}
	return heat, err
}

func (s *MySQL) AdvanceEngagementGrowth(ctx context.Context, now time.Time) error {
	dramas, err := s.ListDramas(ctx, DramaFilter{})
	if err != nil {
		return err
	}
	for _, drama := range dramas {
		if err := s.advanceDramaEngagement(ctx, drama, now); err != nil {
			return err
		}
	}
	_, err = s.db.ExecContext(ctx, `
		UPDATE episode_engagement_heat
		SET likes=likes + GREATEST(1, CEILING(likes * (0.008 + RAND() * 0.004))),
		    comments=comments + GREATEST(1, CEILING(comments * (0.008 + RAND() * 0.004))),
		    favorites=favorites + GREATEST(1, CEILING(favorites * (0.008 + RAND() * 0.004))),
		    shares=shares + GREATEST(1, CEILING(shares * (0.008 + RAND() * 0.004))),
		    next_growth_at=?, updated_at=?
		WHERE next_growth_at <= ?`, now.UTC().Add(engagementGrowthInterval), now.UTC(), now.UTC())
	return err
}

func (s *MySQL) PreloadEpisodeEngagement(ctx context.Context, dramaID string, episodeNumber int) (EpisodeEngagement, error) {
	if strings.TrimSpace(dramaID) == "" || episodeNumber < 1 {
		return EpisodeEngagement{}, ErrInvalidInput
	}
	now := time.Now().UTC()
	initial := newEpisodeEngagement(dramaID, episodeNumber, now)
	_, err := s.db.ExecContext(ctx, `
		INSERT IGNORE INTO episode_engagement_heat
			(drama_id, episode_number, likes, comments, favorites, shares, next_growth_at, updated_at)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
		initial.DramaID, initial.EpisodeNumber, initial.Likes, initial.Comments,
		initial.Favorites, initial.Shares, initial.NextGrowthAt, initial.UpdatedAt)
	if err != nil {
		return EpisodeEngagement{}, err
	}
	heat := EpisodeEngagement{DramaID: dramaID, EpisodeNumber: episodeNumber}
	err = s.db.QueryRowContext(ctx, `
		SELECT likes, comments, favorites, shares, next_growth_at, updated_at
		FROM episode_engagement_heat WHERE drama_id=? AND episode_number=?`,
		dramaID, episodeNumber).Scan(&heat.Likes, &heat.Comments, &heat.Favorites, &heat.Shares, &heat.NextGrowthAt, &heat.UpdatedAt)
	return heat, err
}

func episodeEngagementKey(dramaID string, episodeNumber int) string {
	return dramaID + "\x00" + strconv.Itoa(episodeNumber)
}

func newEpisodeEngagement(dramaID string, episodeNumber int, now time.Time) EpisodeEngagement {
	return EpisodeEngagement{
		DramaID:       dramaID,
		EpisodeNumber: episodeNumber,
		Likes:         randomEpisodeEngagementCount(),
		Comments:      randomEpisodeEngagementCount(),
		Favorites:     randomEpisodeEngagementCount(),
		Shares:        randomEpisodeEngagementCount(),
		NextGrowthAt:  now.UTC().Add(engagementGrowthInterval),
		UpdatedAt:     now.UTC(),
	}
}

func randomEpisodeEngagementCount() int64 {
	return minimumEpisodeEngagement + rand.Int63n(maximumEpisodeEngagement-minimumEpisodeEngagement+1)
}

func advanceEpisodeEngagementCount(current int64, randomFraction float64) int64 {
	if math.IsNaN(randomFraction) || randomFraction < 0 {
		randomFraction = 0
	} else if randomFraction >= 1 {
		randomFraction = math.Nextafter(1, 0)
	}
	step := int64(math.Ceil(float64(current) * (0.008 + randomFraction*0.004)))
	if step < 1 {
		step = 1
	}
	return current + step
}

func advanceEpisodeEngagement(current EpisodeEngagement, now time.Time) EpisodeEngagement {
	current.Likes = advanceEpisodeEngagementCount(current.Likes, rand.Float64())
	current.Comments = advanceEpisodeEngagementCount(current.Comments, rand.Float64())
	current.Favorites = advanceEpisodeEngagementCount(current.Favorites, rand.Float64())
	current.Shares = advanceEpisodeEngagementCount(current.Shares, rand.Float64())
	current.NextGrowthAt = now.UTC().Add(engagementGrowthInterval)
	current.UpdatedAt = now.UTC()
	return current
}

func (s *MySQL) advanceDramaEngagement(ctx context.Context, drama Drama, now time.Time) error {
	transaction, err := s.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer transaction.Rollback()
	if _, err := transaction.ExecContext(ctx, `
		INSERT IGNORE INTO drama_engagement_heat (drama_id, next_growth_at)
		VALUES (?, ?)`, drama.ID, now.UTC()); err != nil {
		return err
	}
	heat := EngagementHeat{DramaID: drama.ID}
	if err := transaction.QueryRowContext(ctx, `
		SELECT likes, comments, favorites, shares, next_growth_at, updated_at
		FROM drama_engagement_heat WHERE drama_id=? FOR UPDATE`, drama.ID).Scan(
		&heat.Likes, &heat.Comments, &heat.Favorites, &heat.Shares,
		&heat.NextGrowthAt, &heat.UpdatedAt,
	); err != nil {
		return err
	}
	if now.Before(heat.NextGrowthAt) {
		return transaction.Commit()
	}
	updated := advanceEngagementHeat(drama.ID, heat, engagementTargets(drama), now)
	_, err = transaction.ExecContext(ctx, `
		UPDATE drama_engagement_heat
		SET likes=?, comments=?, favorites=?, shares=?, next_growth_at=?, updated_at=?
		WHERE drama_id=?`,
		updated.Likes, updated.Comments, updated.Favorites, updated.Shares,
		updated.NextGrowthAt, updated.UpdatedAt, drama.ID,
	)
	if err != nil {
		return err
	}
	return transaction.Commit()
}

func engagementTargets(drama Drama) engagementTarget {
	plays := engagementPlayCount(drama)
	return engagementTarget{
		likes:     ratioTarget(plays, 3, 100),
		comments:  ratioTarget(plays, 2, 1000),
		favorites: ratioTarget(plays, 1, 100),
		shares:    ratioTarget(plays, 1, 1000),
	}
}

func engagementPlayCount(drama Drama) int64 {
	if count := parseEngagementCount(drama.Views); count > 0 {
		return count
	}
	if count := parseEngagementCount(drama.Heat); count > 0 {
		return count
	}
	return 1000
}

func parseEngagementCount(raw string) int64 {
	value := strings.TrimSpace(raw)
	value = strings.NewReplacer(
		",", "", "，", "", " ", "", "+", "",
		"次播放", "", "播放量", "", "播放", "", "次", "", "人次", "", "人", "",
	).Replace(value)
	multiplier := float64(1)
	for _, suffix := range []struct {
		text  string
		value float64
	}{{"亿", 100000000}, {"万", 10000}, {"千", 1000}, {"w", 10000}, {"W", 10000}, {"k", 1000}, {"K", 1000}} {
		if strings.HasSuffix(value, suffix.text) {
			value = strings.TrimSuffix(value, suffix.text)
			multiplier = suffix.value
			break
		}
	}
	number, err := strconv.ParseFloat(value, 64)
	if err != nil || number <= 0 || math.IsNaN(number) || math.IsInf(number, 0) {
		return 0
	}
	result := number * multiplier
	if result >= float64(int64(^uint64(0)>>1)) {
		return int64(^uint64(0) >> 1)
	}
	return int64(math.Round(result))
}

func ratioTarget(plays, numerator, denominator int64) int64 {
	target := int64(math.Ceil(float64(plays) * float64(numerator) / float64(denominator)))
	if target < 1 {
		return 1
	}
	return target
}

func advanceEngagementHeat(dramaID string, current EngagementHeat, target engagementTarget, now time.Time) EngagementHeat {
	current.DramaID = dramaID
	current.Likes += engagementGrowthStep(current.Likes, target.likes, rand.Float64())
	current.Comments += engagementGrowthStep(current.Comments, target.comments, rand.Float64())
	current.Favorites += engagementGrowthStep(current.Favorites, target.favorites, rand.Float64())
	current.Shares += engagementGrowthStep(current.Shares, target.shares, rand.Float64())
	current.NextGrowthAt = now.UTC().Add(engagementGrowthInterval)
	current.UpdatedAt = now.UTC()
	return current
}

func engagementGrowthStep(current, target int64, randomFraction float64) int64 {
	gap := target - current
	if gap <= 0 {
		return 0
	}
	if math.IsNaN(randomFraction) || randomFraction < 0 {
		randomFraction = 0
	} else if randomFraction >= 1 {
		randomFraction = math.Nextafter(1, 0)
	}
	rate := 0.008 + randomFraction*0.004
	step := int64(math.Ceil(float64(gap) * rate))
	if step < 1 {
		step = 1
	}
	if step > gap {
		return gap
	}
	return step
}
