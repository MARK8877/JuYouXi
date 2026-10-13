package store

import (
	"context"
	"testing"
	"time"
)

func TestMemoryStoreRoundTripsDramaAndFollowing(t *testing.T) {
	ctx := context.Background()
	s := NewMemory()
	drama := Drama{ID: "hongguo:1", Source: "hongguo", Title: "测试剧", Name: "测试剧", CategoryName: "剧情", TotalEpisode: 12}
	if err := s.UpsertDrama(ctx, drama); err != nil {
		t.Fatal(err)
	}
	got, found, err := s.GetDrama(ctx, drama.ID)
	if err != nil || !found || got.Title != drama.Title {
		t.Fatalf("get drama = %#v, %v, %v", got, found, err)
	}

	saved := true
	entry, err := s.UpdateFollowing(ctx, "viewer-1", FollowInput{DramaID: drama.ID, Saved: &saved})
	if err != nil {
		t.Fatal(err)
	}
	if !entry.Saved || entry.DramaID != drama.ID {
		t.Fatalf("following = %#v", entry)
	}
}

func TestMemoryStoreRoundTripsPlaybackHistory(t *testing.T) {
	ctx := context.Background()
	s := NewMemory()
	drama := Drama{
		ID:           "hongguo:history-1",
		Source:       "hongguo",
		Title:        "观看记录测试剧",
		Name:         "观看记录测试剧",
		CategoryName: "古装",
		TotalEpisode: 12,
	}
	if err := s.UpsertDrama(ctx, drama); err != nil {
		t.Fatal(err)
	}

	entry, err := s.RecordPlaybackHistory(ctx, "viewer-1", PlaybackHistoryInput{
		DramaID:         drama.ID,
		EpisodeNumber:   3,
		PositionSeconds: 18,
		DurationSeconds: 42,
	})
	if err != nil {
		t.Fatal(err)
	}
	if entry.DramaID != drama.ID || entry.Title != drama.Title || entry.EpisodeNumber != 3 {
		t.Fatalf("history entry = %#v", entry)
	}

	entries, err := s.ListPlaybackHistory(ctx, "viewer-1")
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 1 || entries[0].PositionSeconds != 18 {
		t.Fatalf("history entries = %#v", entries)
	}
}

func TestEpisodeEngagementIsGeneratedOncePerDramaAndEpisode(t *testing.T) {
	ctx := context.Background()
	store := NewMemory()
	drama := Drama{ID: "hongguo:episode-engagement-1", Title: "按集互动测试剧"}
	if err := store.UpsertDrama(ctx, drama); err != nil {
		t.Fatal(err)
	}

	first, err := store.PreloadEpisodeEngagement(ctx, drama.ID, 1)
	if err != nil {
		t.Fatal(err)
	}
	repeated, err := store.PreloadEpisodeEngagement(ctx, drama.ID, 1)
	if err != nil {
		t.Fatal(err)
	}
	second, err := store.PreloadEpisodeEngagement(ctx, drama.ID, 2)
	if err != nil {
		t.Fatal(err)
	}
	if first != repeated {
		t.Fatalf("preloading an episode must return its stable counts: first=%+v repeated=%+v", first, repeated)
	}
	for _, count := range []int64{first.Likes, first.Comments, first.Favorites, first.Shares, second.Likes, second.Comments, second.Favorites, second.Shares} {
		if count < 1000 || count > 9999 {
			t.Fatalf("initial episode count = %d, want 1000..9999", count)
		}
	}
	if first.DramaID != drama.ID || first.EpisodeNumber != 1 || second.EpisodeNumber != 2 {
		t.Fatalf("episode identities = first:%+v second:%+v", first, second)
	}
}

func TestEpisodeEngagementGrowsOnlyAfterItsTenMinuteCycle(t *testing.T) {
	ctx := context.Background()
	store := NewMemory()
	drama := Drama{ID: "hongguo:episode-engagement-growth", Title: "按集增长测试剧"}
	if err := store.UpsertDrama(ctx, drama); err != nil {
		t.Fatal(err)
	}
	createdAt := time.Now().UTC()
	first, err := store.PreloadEpisodeEngagement(ctx, drama.ID, 1)
	if err != nil {
		t.Fatal(err)
	}
	if err := store.AdvanceEngagementGrowth(ctx, createdAt.Add(9*time.Minute)); err != nil {
		t.Fatal(err)
	}
	tooSoon, err := store.PreloadEpisodeEngagement(ctx, drama.ID, 1)
	if err != nil {
		t.Fatal(err)
	}
	if tooSoon != first {
		t.Fatalf("episode counts grew before the ten-minute cycle: first=%+v tooSoon=%+v", first, tooSoon)
	}
	if err := store.AdvanceEngagementGrowth(ctx, createdAt.Add(11*time.Minute)); err != nil {
		t.Fatal(err)
	}
	second, err := store.PreloadEpisodeEngagement(ctx, drama.ID, 1)
	if err != nil {
		t.Fatal(err)
	}
	if second.Likes <= first.Likes || second.Comments <= first.Comments || second.Favorites <= first.Favorites || second.Shares <= first.Shares {
		t.Fatalf("due episode growth must advance every metric: first=%+v second=%+v", first, second)
	}
}

func TestMemoryEngagementGrowthIsBoundedAndRunsOncePerTenMinuteCycle(t *testing.T) {
	ctx := context.Background()
	store := NewMemory()
	drama := Drama{ID: "hongguo:engagement-1", Views: "10万次播放"}
	if err := store.UpsertDrama(ctx, drama); err != nil {
		t.Fatal(err)
	}
	now := time.Date(2026, 10, 13, 10, 0, 0, 0, time.UTC)
	if err := store.AdvanceEngagementGrowth(ctx, now); err != nil {
		t.Fatal(err)
	}
	first, err := store.GetEngagementHeat(ctx, drama.ID)
	if err != nil {
		t.Fatal(err)
	}
	if first.Likes <= 0 || first.Comments <= 0 || first.Favorites <= 0 || first.Shares <= 0 {
		t.Fatalf("first growth must advance all counters: %+v", first)
	}
	target := engagementTargets(drama)
	if first.Likes > target.likes || first.Comments > target.comments || first.Favorites > target.favorites || first.Shares > target.shares {
		t.Fatalf("growth exceeded target: heat=%+v target=%+v", first, target)
	}

	if err := store.AdvanceEngagementGrowth(ctx, now.Add(9*time.Minute)); err != nil {
		t.Fatal(err)
	}
	tooSoon, err := store.GetEngagementHeat(ctx, drama.ID)
	if err != nil {
		t.Fatal(err)
	}
	if tooSoon != first {
		t.Fatalf("growth ran before the next cycle: first=%+v tooSoon=%+v", first, tooSoon)
	}

	if err := store.AdvanceEngagementGrowth(ctx, now.Add(10*time.Minute)); err != nil {
		t.Fatal(err)
	}
	second, err := store.GetEngagementHeat(ctx, drama.ID)
	if err != nil {
		t.Fatal(err)
	}
	if second.Likes < first.Likes || second.Comments < first.Comments || second.Favorites < first.Favorites || second.Shares < first.Shares {
		t.Fatalf("growth must be monotonic: first=%+v second=%+v", first, second)
	}
	if second == first {
		t.Fatal("a due growth cycle should advance at least one counter")
	}
}

func TestEngagementGrowthStepUsesRandomFractionWithinApprovedRange(t *testing.T) {
	const current, target = int64(10_000), int64(100_000)
	minimum := engagementGrowthStep(current, target, 0)
	maximum := engagementGrowthStep(current, target, 0.999999)
	if minimum < 720 || minimum > 721 {
		t.Fatalf("minimum random growth = %d, want about 0.8%% of remaining target", minimum)
	}
	if maximum < 1080 || maximum > 1081 {
		t.Fatalf("maximum random growth = %d, want about 1.2%% of remaining target", maximum)
	}
	if maximum <= minimum {
		t.Fatalf("random fractions did not vary growth: minimum=%d maximum=%d", minimum, maximum)
	}
}

func TestEngagementTargetsParseChinesePlayCountUnits(t *testing.T) {
	tests := []struct {
		name  string
		views string
		want  int64
	}{
		{name: "plain integer", views: "12345", want: 12345},
		{name: "ten thousand", views: "12.5万次播放", want: 125000},
		{name: "hundred million", views: "1.2亿", want: 120000000},
		{name: "fallback", views: "暂无", want: 1000},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			got := engagementPlayCount(Drama{Views: test.views})
			if got != test.want {
				t.Fatalf("engagementPlayCount(%q) = %d, want %d", test.views, got, test.want)
			}
		})
	}
}
