class Episode {
  const Episode({
    required this.number,
    required this.title,
    this.videoUrl,
    this.posterUrl,
    this.durationSeconds,
    this.likes = 0,
    this.comments = 0,
    this.favorites = 0,
    this.shares = 0,
  });

  final int number;
  final String title;
  final String? videoUrl;
  final String? posterUrl;
  final int? durationSeconds;
  final int likes;
  final int comments;
  final int favorites;
  final int shares;

  Episode copyWith({
    int? number,
    String? title,
    String? videoUrl,
    String? posterUrl,
    int? durationSeconds,
    int? likes,
    int? comments,
    int? favorites,
    int? shares,
  }) {
    return Episode(
      number: number ?? this.number,
      title: title ?? this.title,
      videoUrl: videoUrl ?? this.videoUrl,
      posterUrl: posterUrl ?? this.posterUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      favorites: favorites ?? this.favorites,
      shares: shares ?? this.shares,
    );
  }

  factory Episode.fromJson(Map<String, dynamic> json, {int? fallbackNumber}) {
    final number =
        _firstInt([
          json['episode'],
          json['episodeNumber'],
          json['episode_number'],
          json['index'],
          json['number'],
        ]) ??
        fallbackNumber ??
        1;
    final title = _firstString([json['title'], json['name']]);
    return Episode(
      number: number,
      title: title.isEmpty ? '第$number集' : title,
      videoUrl: _httpUrl([
        json['videoUrl'],
        json['video_url'],
        json['playUrl'],
        json['play_url'],
        json['m3u8'],
        json['url'],
      ]),
      posterUrl: _httpUrl([
        json['posterUrl'],
        json['poster_url'],
        json['coverUrl'],
        json['cover_url'],
        json['cover'],
        json['poster'],
        json['thumbnail'],
      ]),
      durationSeconds: _firstInt([
        json['duration'],
        json['durationSeconds'],
        json['duration_seconds'],
      ]),
      likes: _firstNonNegativeInt([json['likes']]) ?? 0,
      comments: _firstNonNegativeInt([json['comments']]) ?? 0,
      favorites: _firstNonNegativeInt([json['favorites']]) ?? 0,
      shares: _firstNonNegativeInt([json['shares']]) ?? 0,
    );
  }
}

class PlaybackSession {
  const PlaybackSession({
    required this.session,
    required this.dramaId,
    required this.title,
    required this.mimeType,
    required this.episodes,
    this.initialIndex = 1,
    this.initialPosition = 0,
    this.source = '',
  });

  final String session;
  final String dramaId;
  final String title;
  final String mimeType;
  final List<Episode> episodes;
  final int initialIndex;
  final double initialPosition;
  final String source;

  factory PlaybackSession.fromJson(Map<String, dynamic> json) {
    final rawEpisodes = json['episodes'];
    final episodes = rawEpisodes is Iterable
        ? [
            for (var index = 0; index < rawEpisodes.length; index++)
              if (rawEpisodes.elementAt(index) is Map)
                Episode.fromJson(
                  Map<String, dynamic>.from(
                    rawEpisodes.elementAt(index) as Map,
                  ),
                  fallbackNumber: index + 1,
                ),
          ]
        : const <Episode>[];
    return PlaybackSession(
      session: _firstString([json['session']]),
      dramaId: _firstString([json['dramaId'], json['drama_id']]),
      title: _firstString([json['title'], json['name']]),
      mimeType: _firstString([json['mimeType'], json['mime_type']]),
      episodes: episodes,
      initialIndex:
          _firstInt([json['initialIndex'], json['initial_index']]) ?? 1,
      initialPosition: _firstDouble([
        json['initialPosition'],
        json['initial_position'],
      ]),
      source: _firstString([json['source']]),
    );
  }
}

class PlaybackStream {
  const PlaybackStream({
    required this.url,
    required this.run,
    required this.durationSeconds,
    this.quality,
    this.source = '',
  });

  final String url;
  final int run;
  final double durationSeconds;
  final int? quality;
  final String source;

  factory PlaybackStream.fromJson(Map<String, dynamic> json) {
    return PlaybackStream(
      url: _firstString([json['url'], json['src']]),
      run: _firstInt([json['run']]) ?? 0,
      durationSeconds: _firstDouble([
        json['duration'],
        json['durationSeconds'],
      ]),
      quality: _firstInt([json['quality']]),
      source: _firstString([json['source']]),
    );
  }
}

class Drama {
  const Drama({
    required this.id,
    required this.title,
    this.description = '',
    this.coverUrl,
    this.episodeCount,
    this.releaseStatus = '',
    this.category = '',
    this.tags = const [],
    this.score = '',
    this.views = '',
    this.heat = '',
    this.episodes = const [],
    this.aiGenerated = false,
  });

  final String id;
  final String title;
  final String description;
  final String? coverUrl;
  final int? episodeCount;
  final String releaseStatus;
  final String category;
  final List<String> tags;
  final String score;
  final String views;
  final String heat;
  final List<Episode> episodes;
  final bool aiGenerated;

  Episode? get firstEpisode => episodes.isEmpty ? null : episodes.first;

  bool get isAiGenerated =>
      aiGenerated || [category, ...tags].any(_isAiTypeLabel);

  factory Drama.fromJson(Map<String, dynamic> json) {
    final count = _firstInt([
      json['totalEpisode'],
      json['total_episode'],
      json['chapterCount'],
      json['chapter_count'],
      json['episodeCount'],
      json['episode_count'],
      json['total'],
    ]);
    final title = _firstString([json['title'], json['name']]);
    final cover = _coverFrom(json);
    final episodes = _episodesFrom(json);
    final aiGenerated =
        [
          json['categoryName'],
          json['category_name'],
          json['category'],
          json['typeName'],
          json['type_name'],
        ].any((value) => _isAiTypeLabel(_firstString([value]))) ||
        _stringList(json['tags']).any(_isAiTypeLabel);
    return Drama(
      id: _firstString([json['id'], json['dramaId'], json['sourceId']]),
      title: title.isEmpty ? '未命名剧集' : title,
      description: _firstString([
        json['desc'],
        json['description'],
        json['intro'],
      ]),
      coverUrl: cover,
      episodeCount: count,
      releaseStatus: _firstString([json['releaseStatus'], json['status']]),
      category: _firstString([
        json['categoryName'],
        json['category_name'],
        json['category'],
        json['typeName'],
      ]),
      tags: _stringList(json['tags']),
      score: _firstString([json['score']]),
      views: _firstString([json['views']]),
      heat: _firstString([json['heat']]),
      episodes: episodes,
      aiGenerated: aiGenerated,
    );
  }

  String get episodeLabel {
    final count = episodeCount;
    if (releaseStatus.isNotEmpty && count != null) {
      return '$releaseStatus · $count集';
    }
    if (count != null) return '$count集';
    return releaseStatus;
  }
}

class FollowingEntry {
  const FollowingEntry({
    required this.dramaId,
    required this.title,
    this.category = '',
    this.saved = false,
    this.completed = false,
    this.knownEpisodes = 0,
  });

  final String dramaId;
  final String title;
  final String category;
  final bool saved;
  final bool completed;
  final int knownEpisodes;

  factory FollowingEntry.fromJson(Map<String, dynamic> json) {
    return FollowingEntry(
      dramaId: _firstString([json['dramaId'], json['id']]),
      title: _firstString([json['title'], json['name']]),
      category: _firstString([json['category'], json['categoryName']]),
      saved: json['saved'] == true,
      completed: json['completed'] == true,
      knownEpisodes:
          _firstInt([json['knownEpisodes'], json['totalEpisode']]) ?? 0,
    );
  }
}

class DramaComment {
  const DramaComment({
    required this.id,
    required this.dramaId,
    required this.authorName,
    required this.content,
    this.parentId,
    this.likeCount = 0,
    this.replyCount = 0,
    this.createdAt,
    this.isSeed = false,
  });

  final String id;
  final String dramaId;
  final String authorName;
  final String content;
  final String? parentId;
  final int likeCount;
  final int replyCount;
  final DateTime? createdAt;
  final bool isSeed;

  DramaComment copyWith({int? replyCount}) => DramaComment(
    id: id,
    dramaId: dramaId,
    authorName: authorName,
    content: content,
    parentId: parentId,
    likeCount: likeCount,
    replyCount: replyCount ?? this.replyCount,
    createdAt: createdAt,
    isSeed: isSeed,
  );

  factory DramaComment.fromJson(Map<String, dynamic> json) {
    final parentId = _firstString([json['parentId'], json['parent_id']]);
    return DramaComment(
      id: _firstString([json['id']]),
      dramaId: _firstString([json['dramaId'], json['drama_id']]),
      authorName: _firstString([json['authorName'], json['author_name']]),
      content: _firstString([json['content']]),
      parentId: parentId.isEmpty ? null : parentId,
      likeCount:
          _firstNonNegativeInt([json['likeCount'], json['like_count']]) ?? 0,
      replyCount:
          _firstNonNegativeInt([json['replyCount'], json['reply_count']]) ?? 0,
      createdAt: _dateTime(json['createdAt'] ?? json['created_at']),
      isSeed: json['isSeed'] == true || json['is_seed'] == true,
    );
  }
}

class DramaComments {
  const DramaComments({
    required this.dramaId,
    required this.data,
    required this.total,
  });

  final String dramaId;
  final List<DramaComment> data;
  final int total;

  factory DramaComments.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final comments = rawData is List
        ? rawData
              .whereType<Map>()
              .map(
                (item) =>
                    DramaComment.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList()
        : const <DramaComment>[];
    return DramaComments(
      dramaId: _firstString([json['dramaId'], json['drama_id']]),
      data: comments,
      total: _firstNonNegativeInt([json['total']]) ?? comments.length,
    );
  }
}

class EngagementHeat {
  const EngagementHeat({
    required this.dramaId,
    required this.simulated,
    this.likes = 0,
    this.comments = 0,
    this.favorites = 0,
    this.shares = 0,
  });

  final String dramaId;
  final bool simulated;
  final int likes;
  final int comments;
  final int favorites;
  final int shares;

  factory EngagementHeat.fromJson(Map<String, dynamic> json) {
    return EngagementHeat(
      dramaId: _firstString([json['dramaId'], json['drama_id']]),
      simulated: json['simulated'] == true,
      likes: _firstNonNegativeInt([json['likes']]) ?? 0,
      comments: _firstNonNegativeInt([json['comments']]) ?? 0,
      favorites: _firstNonNegativeInt([json['favorites']]) ?? 0,
      shares: _firstNonNegativeInt([json['shares']]) ?? 0,
    );
  }
}

class CommentSubmission {
  const CommentSubmission({
    required this.comment,
    required this.total,
    this.parentReplyCount,
  });

  final DramaComment comment;
  final int total;
  final int? parentReplyCount;

  factory CommentSubmission.fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! Map) throw const FormatException('评论响应缺少 data');
    return CommentSubmission(
      comment: DramaComment.fromJson(Map<String, dynamic>.from(data)),
      total: _firstNonNegativeInt([json['total']]) ?? 0,
      parentReplyCount: _firstNonNegativeInt([json['parentReplyCount']]),
    );
  }
}

class PlaybackHistoryEntry {
  const PlaybackHistoryEntry({
    required this.dramaId,
    required this.title,
    this.source = '',
    this.category = '',
    this.episodeNumber = 1,
    this.positionSeconds = 0,
    this.durationSeconds = 0,
    this.watchedAt,
  });

  final String dramaId;
  final String title;
  final String source;
  final String category;
  final int episodeNumber;
  final int positionSeconds;
  final int durationSeconds;
  final DateTime? watchedAt;

  factory PlaybackHistoryEntry.fromJson(Map<String, dynamic> json) {
    return PlaybackHistoryEntry(
      dramaId: _firstString([json['dramaId'], json['id']]),
      title: _firstString([json['title'], json['name']]),
      source: _firstString([json['source']]),
      category: _firstString([json['category'], json['categoryName']]),
      episodeNumber:
          _firstPositiveInt([json['episodeNumber'], json['episode']]) ?? 1,
      positionSeconds: _firstNonNegativeInt([json['positionSeconds']]) ?? 0,
      durationSeconds: _firstNonNegativeInt([json['durationSeconds']]) ?? 0,
      watchedAt: _dateTime(json['watchedAt']),
    );
  }
}

class ViewerInfo {
  const ViewerInfo({
    this.ready = false,
    this.sources = const [],
    this.onlineOnly = false,
    this.account,
  });

  final bool ready;
  final List<String> sources;
  final bool onlineOnly;
  final String? account;

  factory ViewerInfo.fromJson(Map<String, dynamic> json) {
    return ViewerInfo(
      ready: json['ready'] == true,
      sources: _stringList(json['sources']),
      onlineOnly: json['onlineOnly'] == true,
      account: json['account'] is String ? json['account'] as String : null,
    );
  }
}

bool _isAiTypeLabel(String value) =>
    value.contains('人工智能') ||
    RegExp(
      r'(^|[^a-z])ai(?:gc)?(?=$|[^a-z])',
      caseSensitive: false,
    ).hasMatch(value);

String _firstString(Iterable<dynamic> values) {
  for (final value in values) {
    final text = _displayText(value);
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _displayText(dynamic value) {
  if (value == null) return '';
  final text = value.toString().trim();
  if ({
    'unknown',
    'null',
    'undefined',
    'none',
    'n/a',
    'na',
    '-',
    '未知',
    '未提供',
  }.contains(text.toLowerCase())) {
    return '';
  }
  return text;
}

int? _firstInt(Iterable<dynamic> values) {
  for (final value in values) {
    if (value is int) return value > 0 ? value : null;
    if (value is num) return value > 0 ? value.toInt() : null;
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null && parsed > 0) return parsed;
  }
  return null;
}

int? _firstPositiveInt(Iterable<dynamic> values) {
  for (final value in values) {
    final parsed = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '');
    if (parsed != null && parsed > 0) return parsed;
  }
  return null;
}

int? _firstNonNegativeInt(Iterable<dynamic> values) {
  for (final value in values) {
    final parsed = value is num
        ? value.toInt()
        : int.tryParse(value?.toString() ?? '');
    if (parsed != null && parsed >= 0) return parsed;
  }
  return null;
}

DateTime? _dateTime(dynamic value) {
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '');
}

double _firstDouble(Iterable<dynamic> values) {
  for (final value in values) {
    if (value is num) return value.toDouble();
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return 0;
}

List<String> _stringList(dynamic value) {
  if (value is Iterable) {
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}

String? _coverFrom(Map<String, dynamic> json) {
  for (final value in [
    json['coverUrl'],
    json['cover_url'],
    json['cover'],
    json['imageUrl'],
    json['image_url'],
    json['image'],
    json['img'],
    json['pic'],
    json['picture'],
    json['poster'],
    json['thumb'],
    json['thumbnail'],
  ]) {
    final url = _coverValue(value);
    if (url != null) return url;
  }
  return null;
}

List<Episode> _episodesFrom(Map<String, dynamic> json) {
  final raw = json['episodes'] ?? json['episodeList'] ?? json['chapters'];
  if (raw is! Iterable) return const [];
  return [
    for (var index = 0; index < raw.length; index++)
      if (raw.elementAt(index) is Map)
        Episode.fromJson(
          Map<String, dynamic>.from(raw.elementAt(index) as Map),
          fallbackNumber: index + 1,
        ),
  ];
}

String? _httpUrl(Iterable<dynamic> values) {
  for (final value in values) {
    final text = _urlText(value);
    if (text == null) continue;
    final uri = Uri.tryParse(text);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return text;
    }
  }
  return null;
}

String? _urlText(dynamic value) {
  if (value is String) {
    final text = _displayText(value);
    return text.isEmpty ? null : text;
  }
  if (value is Map) {
    for (final key in ['url', 'src', 'href']) {
      final text = _displayText(value[key]);
      if (text.isNotEmpty) return text;
    }
  }
  return null;
}

String? _coverValue(dynamic value) {
  if (value is String) {
    final text = _displayText(value);
    if (text.isNotEmpty) return text;
  }
  if (value is Map) {
    for (final key in ['url', 'src', 'href']) {
      final nested = value[key];
      final nestedText = _displayText(nested);
      if (nestedText.isNotEmpty) return nestedText;
    }
  }
  return null;
}
