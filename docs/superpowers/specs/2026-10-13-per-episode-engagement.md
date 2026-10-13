# Per-Episode Simulated Engagement

## Goal

Give each short-drama episode its own persisted simulated like, comment, favorite, and share counts, generated when the episode is preloaded. Keep episode selection non-blocking for playback and start the selected episode immediately.

## Behavior

- The persistence key is `(drama_id, episode_number)`.
- The first preload creates four independent integer counters in the inclusive range 1,000–9,999. Repeated preload requests return the existing row without resetting it.
- The Flutter `Episode` model carries all four counters. The player preloads the current episode and its next episode after playback metadata becomes available, and refreshes the active episode through the existing ten-minute growth cycle.
- Existing ten-minute simulated growth remains, but advances only episode rows that have been preloaded. Each metric grows by a random 0.8%–1.2% per due cycle.
- On the details page, opening the episode picker does not pause the current player. Selecting a different episode keeps the existing vertical `PageView` activation path so the new active page starts playback immediately. The feed-to-details navigation behavior is unchanged.
- Add a `POST /api/ui/episode-engagement` API and document it in OpenAPI. Do not remove the existing drama-level engagement API in this change.

## Constraints

- No new dependencies.
- No unrelated UI changes.
- Do not stop or restart the running server.
- Database table changes are additive in `schema.sql`; do not apply a live migration in this implementation.
