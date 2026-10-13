import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiException implements Exception {
  const ApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

class LibraryApi {
  LibraryApi({String? baseUrl, String? playbackBaseUrl, http.Client? client})
    : baseUrl = Uri.parse(
        baseUrl ??
            const String.fromEnvironment(
              'API_BASE_URL',
              defaultValue: 'http://127.0.0.1:9010',
            ),
      ),
      playbackBaseUrl = Uri.parse(
        playbackBaseUrl ??
            const String.fromEnvironment(
              'PLAYBACK_BASE_URL',
              defaultValue: 'http://127.0.0.1:9000',
            ),
      ),
      _client = client ?? http.Client();

  final Uri baseUrl;
  final Uri playbackBaseUrl;
  final http.Client _client;
  String? _cookie;

  Future<List<Drama>> fetchDramas() async {
    final json = await _get('/api/ui/dramas', query: {'source': 'hongguo'});
    return decodeDramaList(json);
  }

  Future<List<Drama>> search(String keyword) async {
    final query = keyword.trim();
    if (query.isEmpty) return const [];
    final json = await _get('/api/ui/search', query: {'q': query});
    return decodeDramaList(json);
  }

  Future<List<FollowingEntry>> fetchFollowing() async {
    final json = await _get('/api/ui/following');
    final data = json['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((item) => FollowingEntry.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<PlaybackHistoryEntry>> fetchPlaybackHistory() async {
    final json = await _get('/api/ui/history');
    final data = json['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map(
          (item) =>
              PlaybackHistoryEntry.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<void> recordPlaybackHistory(
    String dramaId, {
    required int episodeNumber,
    int positionSeconds = 0,
    int durationSeconds = 0,
  }) async {
    await _post('/api/ui/history', {
      'dramaId': dramaId,
      'episodeNumber': episodeNumber,
      'positionSeconds': positionSeconds,
      'durationSeconds': durationSeconds,
    });
  }

  Future<DramaComments> fetchComments(String dramaId) async {
    final json = await _get('/api/ui/comments', query: {'dramaId': dramaId});
    return DramaComments.fromJson(json);
  }

  Future<EngagementHeat> fetchEngagementHeat(String dramaId) async {
    final json = await _get('/api/ui/engagement', query: {'dramaId': dramaId});
    return EngagementHeat.fromJson(json);
  }

  Future<Episode> preloadEpisodeEngagement(
    String dramaId,
    int episodeNumber,
  ) async {
    final json = await _post('/api/ui/episode-engagement', {
      'dramaId': dramaId,
      'episodeNumber': episodeNumber,
    });
    return Episode.fromJson(json, fallbackNumber: episodeNumber);
  }

  Future<CommentSubmission> submitComment(
    String dramaId,
    String content, {
    String? parentId,
  }) async {
    final payload = <String, dynamic>{'dramaId': dramaId, 'content': content};
    if (parentId != null) payload['parentId'] = parentId;
    final json = await _post('/api/ui/comments', payload);
    try {
      return CommentSubmission.fromJson(json);
    } on FormatException {
      throw const ApiException('评论暂未保存，请重试', 500);
    }
  }

  Future<void> setFollowing(
    String dramaId, {
    bool? saved,
    bool? completed,
  }) async {
    final payload = <String, dynamic>{'dramaId': dramaId};
    if (saved != null) payload['saved'] = saved;
    if (completed != null) payload['completed'] = completed;
    await _post('/api/ui/following', payload);
  }

  Future<ViewerInfo> fetchViewer() async {
    final json = await _get('/api/ui/viewer');
    return ViewerInfo.fromJson(json);
  }

  Future<PlaybackSession> openPlayback(String dramaId) async {
    final json = await _postAt(playbackBaseUrl, '/api/ui/playback/open', {
      'dramaId': dramaId,
      'resume': false,
      'fromHistory': false,
    });
    return PlaybackSession.fromJson(json);
  }

  Future<PlaybackStream> openPlaybackStream(
    String session, {
    required int episode,
    int start = 0,
    int quality = 0,
    int version = 1,
  }) async {
    final json = await _postAt(playbackBaseUrl, '/api/ui/playback/hls/open', {
      'session': session,
      'episode': episode,
      'start': start,
      'quality': quality,
      'version': version,
    });
    return PlaybackStream.fromJson(json);
  }

  Future<void> closePlayback(String session) async {
    await _postAt(playbackBaseUrl, '/api/ui/playback/control', {
      'session': session,
      'action': 'close',
    });
  }

  Uri playbackUrl(String rawUrl) {
    final parsed = Uri.tryParse(rawUrl);
    if (parsed != null && parsed.hasScheme) return parsed;
    return playbackBaseUrl.resolve(rawUrl);
  }

  Uri? coverUrl(Drama drama) {
    final raw = drama.coverUrl;
    if (raw == null || raw.isEmpty) return null;
    final parsed = Uri.tryParse(raw);
    if (parsed == null || !parsed.hasScheme) return null;
    return _resolve('/api/ui/image').replace(queryParameters: {'url': raw});
  }

  Uri _resolve(String path) => baseUrl.resolve(path);

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = _resolve(path).replace(queryParameters: query);
    final response = await _client.get(uri, headers: _headers());
    _captureCookie(response);
    return _decode(response);
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    return _postAt(baseUrl, path, body);
  }

  Future<Map<String, dynamic>> _postAt(
    Uri root,
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.post(
      root.resolve(path),
      headers: {..._headers(), 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    _captureCookie(response);
    return _decode(response);
  }

  Map<String, String> _headers() {
    final headers = <String, String>{'Accept': 'application/json'};
    final cookie = _cookie;
    if (cookie != null) headers['Cookie'] = cookie;
    return headers;
  }

  void _captureCookie(http.Response response) {
    final setCookie = response.headers['set-cookie'];
    if (setCookie == null) return;
    final pair = setCookie.split(';').first.trim();
    if (pair.startsWith('juku_viewer_id=')) _cookie = pair;
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> json = const {};
    if (response.body.isNotEmpty) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) json = Map<String, dynamic>.from(decoded);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = json['error'];
      throw ApiException(
        error is String ? error : '请求失败，请稍后重试',
        response.statusCode,
      );
    }
    return json;
  }
}

List<Drama> decodeDramaList(Map<String, dynamic> json) {
  final data = json['data'];
  if (data is! List) return const [];
  return data
      .whereType<Map>()
      .map((item) => Drama.fromJson(Map<String, dynamic>.from(item)))
      .toList();
}
