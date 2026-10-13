CREATE DATABASE IF NOT EXISTS juku_library CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE juku_library;

CREATE TABLE IF NOT EXISTS dramas (
  id VARCHAR(128) PRIMARY KEY,
  source VARCHAR(32) NOT NULL DEFAULT 'hongguo',
  source_id VARCHAR(96) NOT NULL,
  vip BOOLEAN NULL,
  title VARCHAR(512) NOT NULL DEFAULT '',
  name VARCHAR(512) NOT NULL DEFAULT '',
  description TEXT NOT NULL,
  intro TEXT NOT NULL,
  category_name VARCHAR(128) NOT NULL DEFAULT '',
  tags_text TEXT NOT NULL,
  total_episode INT NULL,
  release_status VARCHAR(32) NOT NULL DEFAULT '',
  payload JSON NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_dramas_source_title (source, title),
  KEY idx_dramas_source_id (source, source_id),
  KEY idx_dramas_updated_at (updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS library_sources (
  source VARCHAR(32) PRIMARY KEY,
  status VARCHAR(32) NOT NULL DEFAULT 'ready',
  count INT NOT NULL DEFAULT 0,
  error_message VARCHAR(1024) NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  revision BIGINT UNSIGNED NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS viewers (
  id VARCHAR(128) PRIMARY KEY,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS following (
  viewer_id VARCHAR(128) NOT NULL,
  drama_id VARCHAR(128) NOT NULL,
  source VARCHAR(32) NOT NULL DEFAULT 'hongguo',
  title VARCHAR(512) NOT NULL DEFAULT '',
  category VARCHAR(128) NOT NULL DEFAULT '',
  saved BOOLEAN NOT NULL DEFAULT FALSE,
  completed BOOLEAN NOT NULL DEFAULT FALSE,
  known_episodes INT NOT NULL DEFAULT 0,
  added_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (viewer_id, drama_id),
  KEY idx_following_viewer_updated (viewer_id, updated_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS playback_history (
  viewer_id VARCHAR(128) NOT NULL,
  drama_id VARCHAR(128) NOT NULL,
  payload JSON NOT NULL,
  watched_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (viewer_id, drama_id),
  KEY idx_history_viewer_watched (viewer_id, watched_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS drama_comments (
  id VARCHAR(128) PRIMARY KEY,
  drama_id VARCHAR(128) NOT NULL,
  parent_id VARCHAR(128) NULL,
  viewer_id VARCHAR(128) NULL,
  seed_index INT NULL,
  author_name VARCHAR(64) NOT NULL DEFAULT '游客',
  content VARCHAR(2000) NOT NULL,
  like_count INT NOT NULL DEFAULT 0,
  reply_count INT NOT NULL DEFAULT 0,
  is_seed BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_drama_comment_seed (drama_id, seed_index),
  KEY idx_drama_comments_feed (drama_id, created_at, id),
  KEY idx_drama_comments_viewer (viewer_id, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS drama_engagement_heat (
  drama_id VARCHAR(128) PRIMARY KEY,
  likes BIGINT UNSIGNED NOT NULL DEFAULT 0,
  comments BIGINT UNSIGNED NOT NULL DEFAULT 0,
  favorites BIGINT UNSIGNED NOT NULL DEFAULT 0,
  shares BIGINT UNSIGNED NOT NULL DEFAULT 0,
  next_growth_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  KEY idx_engagement_next_growth (next_growth_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS episode_engagement_heat (
  drama_id VARCHAR(128) NOT NULL,
  episode_number INT NOT NULL,
  likes BIGINT UNSIGNED NOT NULL,
  comments BIGINT UNSIGNED NOT NULL,
  favorites BIGINT UNSIGNED NOT NULL,
  shares BIGINT UNSIGNED NOT NULL,
  next_growth_at DATETIME(6) NOT NULL,
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (drama_id, episode_number),
  KEY idx_episode_engagement_next_growth (next_growth_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS download_tasks (
  id VARCHAR(128) PRIMARY KEY,
  viewer_id VARCHAR(128) NOT NULL,
  drama_id VARCHAR(128) NOT NULL,
  title VARCHAR(512) NOT NULL DEFAULT '',
  quality INT NOT NULL DEFAULT 0,
  status VARCHAR(32) NOT NULL DEFAULT 'queued',
  progress INT NOT NULL DEFAULT 0,
  payload JSON NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  KEY idx_tasks_viewer_updated (viewer_id, updated_at),
  KEY idx_tasks_drama (drama_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ranking_boards (
  id VARCHAR(128) PRIMARY KEY,
  source VARCHAR(32) NOT NULL DEFAULT 'hongguo',
  name VARCHAR(256) NOT NULL DEFAULT '',
  payload JSON NOT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ranking_items (
  board_id VARCHAR(128) NOT NULL,
  page INT NOT NULL,
  rank_no INT NOT NULL,
  drama_id VARCHAR(128) NOT NULL,
  payload JSON NOT NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (board_id, page, rank_no),
  KEY idx_ranking_drama (drama_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
