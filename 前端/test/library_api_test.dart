import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:juyouxi/src/library_api.dart';
import 'package:juyouxi/src/models.dart';

class _PlaybackClient extends http.BaseClient {
  final requests = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final payload = request.url.path.endsWith('/playback/open')
        ? {
            'session': 'session-1',
            'dramaId': 'hongguo:d-1',
            'episodes': [
              {'episode': 1, 'title': '第1集'},
            ],
          }
        : {
            'run': 1,
            'duration': 43.283,
            'url': '/api/ui/playback/hls/index.m3u8?session=session-1',
          };
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(payload))),
      200,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _HistoryClient extends http.BaseClient {
  final requests = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final payload = request.method == 'GET'
        ? {
            'data': [
              {
                'dramaId': 'hongguo:history-1',
                'source': 'hongguo',
                'title': '观看记录测试剧',
                'category': '古装',
                'episodeNumber': 3,
                'positionSeconds': 18,
                'durationSeconds': 42,
                'watchedAt': '2026-09-24T10:00:00Z',
              },
            ],
          }
        : {
            'ok': true,
            'entry': {
              'dramaId': 'hongguo:history-1',
              'title': '观看记录测试剧',
              'episodeNumber': 3,
              'positionSeconds': 18,
              'durationSeconds': 42,
              'watchedAt': '2026-09-24T10:00:00Z',
            },
          };
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(payload))),
      200,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _CommentClient extends http.BaseClient {
  final requests = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final body = request.method == 'POST' && request is http.Request
        ? jsonDecode(request.body) as Map<String, dynamic>
        : <String, dynamic>{};
    final parentId = body['parentId'] as String?;
    final comment = {
      'id': request.method == 'GET'
          ? 'seed-1'
          : parentId == null
          ? 'user-1'
          : 'reply-1',
      'dramaId': 'hongguo:comments-1',
      'authorName': request.method == 'GET' ? '追剧小鱼' : '游客',
      'content': request.method == 'GET' ? '这部太好看了' : '很好看',
      'parentId': parentId,
      'likeCount': 3,
      'replyCount': 0,
      'createdAt': '2026-09-24T10:00:00Z',
      'isSeed': request.method == 'GET',
    };
    final payload = request.method == 'GET'
        ? {
            'dramaId': 'hongguo:comments-1',
            'total': 1,
            'data': [comment],
          }
        : {
            'total': parentId == null ? 2 : 3,
            if (parentId != null) 'parentReplyCount': 1,
            'data': comment,
          };
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(payload))),
      200,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _EngagementClient extends http.BaseClient {
  final requests = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode({
            'dramaId': 'hongguo:engagement-1',
            'simulated': true,
            'likes': 123,
            'comments': 8,
            'favorites': 34,
            'shares': 5,
          }),
        ),
      ),
      200,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _EpisodeEngagementClient extends http.BaseClient {
  final requests = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    return http.StreamedResponse(
      Stream.value(
        utf8.encode(
          jsonEncode({
            'dramaId': 'hongguo:episode-engagement-1',
            'episodeNumber': 2,
            'likes': 4321,
            'comments': 2345,
            'favorites': 6789,
            'shares': 1234,
          }),
        ),
      ),
      200,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

void main() {
  test('parses drama metadata and a nested cover URL', () {
    final drama = Drama.fromJson({
      'id': 'd-1',
      'title': '春风入卷',
      'cover': {'url': 'https://img.example/cover.webp'},
      'totalEpisode': 36,
      'releaseStatus': '更新中',
      'categoryName': '古装',
    });

    expect(drama.title, '春风入卷');
    expect(drama.coverUrl, 'https://img.example/cover.webp');
    expect(drama.episodeLabel, '更新中 · 36集');
  });

  test('decodes the server drama envelope', () {
    final dramas = decodeDramaList({
      'data': [
        {'id': 'd-1', 'title': '春风入卷'},
      ],
    });

    expect(dramas.single.id, 'd-1');
  });

  test('fetches and parses simulated engagement heat', () async {
    final client = _EngagementClient();
    final api = LibraryApi(baseUrl: 'http://example.test', client: client);

    final heat = await api.fetchEngagementHeat('hongguo:engagement-1');

    expect(heat.simulated, isTrue);
    expect(heat.likes, 123);
    expect(heat.comments, 8);
    expect(heat.favorites, 34);
    expect(heat.shares, 5);
    expect(
      client.requests.single.url.queryParameters['dramaId'],
      'hongguo:engagement-1',
    );
    client.close();
  });

  test('preloads persisted engagement for one episode', () async {
    final client = _EpisodeEngagementClient();
    final api = LibraryApi(baseUrl: 'http://example.test', client: client);

    final episode = await api.preloadEpisodeEngagement(
      'hongguo:episode-engagement-1',
      2,
    );

    expect(episode.number, 2);
    expect(episode.likes, 4321);
    expect(episode.comments, 2345);
    expect(episode.favorites, 6789);
    expect(episode.shares, 1234);
    final request = client.requests.single as http.Request;
    expect(request.method, 'POST');
    expect(request.url.path, '/api/ui/episode-engagement');
    expect(jsonDecode(request.body), {
      'dramaId': 'hongguo:episode-engagement-1',
      'episodeNumber': 2,
    });
    client.close();
  });

  test('does not expose unknown metadata as user-facing labels', () {
    final drama = Drama.fromJson({
      'id': 'd-2',
      'title': '夜行记',
      'releaseStatus': 'unknown',
      'categoryName': 'UNKNOWN',
      'totalEpisode': 'unknown',
      'coverUrl': 'unknown',
    });

    expect(drama.releaseStatus, isEmpty);
    expect(drama.category, isEmpty);
    expect(drama.episodeCount, isNull);
    expect(drama.episodeLabel, isEmpty);
    expect(drama.coverUrl, isNull);
  });

  test('parses the first episode video and poster fields', () {
    final drama = Drama.fromJson({
      'id': 'd-3',
      'title': '假面宫女',
      'episodes': [
        {
          'episode': 1,
          'title': '第1集',
          'videoUrl': 'https://video.example/one.m3u8',
          'posterUrl': 'https://img.example/one.webp',
        },
      ],
    });

    expect(drama.episodes, hasLength(1));
    expect(drama.firstEpisode?.number, 1);
    expect(drama.firstEpisode?.title, '第1集');
    expect(drama.firstEpisode?.videoUrl, 'https://video.example/one.m3u8');
    expect(drama.firstEpisode?.posterUrl, 'https://img.example/one.webp');
  });

  test('keeps the first episode but omits an unknown video URL', () {
    final drama = Drama.fromJson({
      'id': 'd-4',
      'title': '待补充剧集',
      'episodes': [
        {'episodeNumber': '1', 'url': 'unknown', 'poster': 'unknown'},
      ],
    });

    expect(drama.firstEpisode, isNotNull);
    expect(drama.firstEpisode?.number, 1);
    expect(drama.firstEpisode?.videoUrl, isNull);
    expect(drama.firstEpisode?.posterUrl, isNull);
  });

  test(
    'keeps episode order for selection even when later URLs are missing',
    () {
      final drama = Drama.fromJson({
        'id': 'd-5',
        'title': '三集短剧',
        'episodes': [
          {'episode': 1, 'title': '开场'},
          {'episode': 2, 'title': '转折', 'videoUrl': 'unknown'},
          {
            'episode': 3,
            'title': '结局',
            'playUrl': 'https://video.example/3.m3u8',
          },
        ],
      });

      expect(drama.episodes.map((episode) => episode.number), [1, 2, 3]);
      expect(drama.episodes[1].videoUrl, isNull);
      expect(drama.episodes[2].videoUrl, 'https://video.example/3.m3u8');
    },
  );

  test('decodes playback session episodes without inventing video URLs', () {
    final session = PlaybackSession.fromJson({
      'session': 'session-1',
      'dramaId': 'hongguo:d-1',
      'title': '假面宫女',
      'mimeType': 'video/mp4; codecs="avc1.42C01F, mp4a.40.2"',
      'initialIndex': 1,
      'episodes': [
        {'index': 1, 'episode': '1', 'title': '第1集', 'total': 54},
      ],
    });

    expect(session.session, 'session-1');
    expect(session.episodes.single.number, 1);
    expect(session.episodes.single.videoUrl, isNull);
    expect(session.episodes.single.title, '第1集');
  });

  test('decodes a relative HLS playback URL', () {
    final stream = PlaybackStream.fromJson({
      'run': 1,
      'duration': 43.283,
      'quality': 1080,
      'url': '/api/ui/playback/hls/index.m3u8?session=session-1',
    });

    expect(stream.run, 1);
    expect(stream.durationSeconds, closeTo(43.283, 0.001));
    expect(stream.url, startsWith('/api/ui/playback/hls/'));
  });

  test('uses the playback service for metadata-only dramas', () async {
    final client = _PlaybackClient();
    final api = LibraryApi(
      baseUrl: 'http://127.0.0.1:9010',
      playbackBaseUrl: 'http://127.0.0.1:9000',
      client: client,
    );

    final session = await api.openPlayback('hongguo:d-1');
    final stream = await api.openPlaybackStream(
      session.session,
      episode: session.episodes.single.number,
    );

    expect(
      client.requests[0].url.toString(),
      'http://127.0.0.1:9000/api/ui/playback/open',
    );
    expect(
      client.requests[1].url.toString(),
      'http://127.0.0.1:9000/api/ui/playback/hls/open',
    );
    expect(
      api.playbackUrl(stream.url).toString(),
      'http://127.0.0.1:9000/api/ui/playback/hls/index.m3u8?session=session-1',
    );
  });

  test('reads and writes playback history through the library API', () async {
    final client = _HistoryClient();
    final api = LibraryApi(client: client);

    final entries = await api.fetchPlaybackHistory();
    expect(entries.single.title, '观看记录测试剧');
    expect(entries.single.episodeNumber, 3);

    await api.recordPlaybackHistory(
      'hongguo:history-1',
      episodeNumber: 3,
      positionSeconds: 18,
      durationSeconds: 42,
    );

    expect(client.requests.map((request) => request.method), ['GET', 'POST']);
    final post = client.requests.last as http.Request;
    final body = jsonDecode(post.body) as Map<String, dynamic>;
    expect(body['episodeNumber'], 3);
    expect(body['positionSeconds'], 18);
  });

  test('reads and submits persistent drama comments', () async {
    final client = _CommentClient();
    final api = LibraryApi(client: client);

    final comments = await api.fetchComments('hongguo:comments-1');
    expect(comments.total, 1);
    expect(comments.data.single.content, '这部太好看了');
    expect(comments.data.single.isSeed, isTrue);

    final posted = await api.submitComment('hongguo:comments-1', '很好看');
    expect(posted.comment.content, '很好看');
    expect(posted.total, 2);
    expect(client.requests.map((request) => request.method), ['GET', 'POST']);
    expect(
      client.requests.first.url.queryParameters['dramaId'],
      'hongguo:comments-1',
    );
    final body =
        jsonDecode((client.requests.last as http.Request).body)
            as Map<String, dynamic>;
    expect(body['content'], '很好看');
    expect(body['dramaId'], 'hongguo:comments-1');

    final reply = await api.submitComment(
      'hongguo:comments-1',
      '回复内容',
      parentId: 'user-1',
    );
    expect(reply.comment.parentId, 'user-1');
    expect(reply.parentReplyCount, 1);
    expect(reply.total, 3);
    final replyBody =
        jsonDecode((client.requests.last as http.Request).body)
            as Map<String, dynamic>;
    expect(replyBody['parentId'], 'user-1');
  });
}
