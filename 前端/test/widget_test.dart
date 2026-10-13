import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
// ignore: depend_on_referenced_packages
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:juyouxi/main.dart';
import 'package:juyouxi/src/drama_widgets.dart';
import 'package:juyouxi/src/library_api.dart';
import 'package:juyouxi/src/models.dart';
import 'package:juyouxi/src/video_feed.dart';

class _ProfileHistoryClient extends http.BaseClient {
  _ProfileHistoryClient({this.hasHistory = true});

  bool hasHistory;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    final payload = switch (path) {
      '/api/ui/viewer' => {
        'ready': true,
        'sources': ['hongguo'],
      },
      '/api/ui/history' => {
        'data': hasHistory
            ? [
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
              ]
            : <dynamic>[],
      },
      '/api/ui/dramas' => {
        'data': [
          {
            'id': 'hongguo:history-1',
            'title': '观看记录测试剧',
            'categoryName': '古装',
            'totalEpisode': 12,
            'episodes': [
              {'episode': 1, 'title': '第1集'},
              {'episode': 2, 'title': '第2集'},
              {'episode': 3, 'title': '第3集'},
            ],
          },
        ],
      },
      _ => {'data': <dynamic>[]},
    };
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(payload))),
      200,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _HomeCarouselClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path == '/api/ui/dramas') {
      return _response(request, {
        'data': [
          for (var index = 1; index <= 12; index++)
            {
              'id': 'home-$index',
              'title': '首页测试短剧$index',
              'categoryName': '古装',
              'releaseStatus': 'finish',
              'totalEpisode': 2,
              'episodes': [
                {'episode': 1, 'title': '第1集'},
                {'episode': 2, 'title': '第2集'},
              ],
            },
        ],
      });
    }
    return _response(request, {
      'error': 'test playback unavailable',
    }, statusCode: 503);
  }

  http.StreamedResponse _response(
    http.BaseRequest request,
    Map<String, Object?> payload, {
    int statusCode = 200,
  }) {
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(payload))),
      statusCode,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _FollowingRecommendationClient extends http.BaseClient {
  _FollowingRecommendationClient({this.dramaCount = 14});

  final int dramaCount;
  int dramaRequests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path == '/api/ui/dramas') dramaRequests++;
    final data = switch (request.url.path) {
      '/api/ui/following' => <String, Object?>{'data': <Object?>[]},
      '/api/ui/dramas' => <String, Object?>{
        'data': [
          for (var index = 1; index <= dramaCount; index++)
            {
              'id': 'heat-$index',
              'title': '热度短剧$index',
              'heat': index == 14
                  ? 'unknown'
                  : index.isOdd
                  ? '${index / 10}万'
                  : '${index * 1000}',
              'views': index == 14 ? '${index * 1000}次播放' : '${index * 1000}',
              'totalEpisode': 8,
            },
        ],
      },
      _ => <String, Object?>{'data': <Object?>[]},
    };
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(data))),
      200,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _FollowingHistoryClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final payload = switch (request.url.path) {
      '/api/ui/following' => {
        'data': [
          {
            'dramaId': 'history-drama',
            'title': '进度测试剧',
            'saved': true,
            'knownEpisodes': 12,
          },
        ],
      },
      '/api/ui/history' => {
        'data': [
          {
            'dramaId': 'history-drama',
            'title': '进度测试剧',
            'episodeNumber': 3,
            'positionSeconds': 20,
            'durationSeconds': 60,
          },
        ],
      },
      '/api/ui/dramas' => {
        'data': [
          {'id': 'history-drama', 'title': '进度测试剧', 'totalEpisode': 20},
        ],
      },
      _ => {'data': <dynamic>[]},
    };
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(payload))),
      200,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _EpisodePlaybackClient extends http.BaseClient {
  int playbackSessionCount = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = request is http.Request
        ? jsonDecode(request.body) as Map<String, dynamic>
        : <String, dynamic>{};
    final episode =
        body['episodeNumber'] as int? ?? body['episode'] as int? ?? 1;
    final payload = switch (request.url.path) {
      '/api/ui/playback/open' => {
        'session': 'episode-session-${++playbackSessionCount}',
        'dramaId': 'episode-play-test',
        'episodes': [
          {'episode': 1, 'title': '第1集'},
          {'episode': 2, 'title': '第2集'},
        ],
      },
      '/api/ui/playback/hls/open' => {
        'run': 1,
        'duration': 60,
        'url': 'https://video.example/episode-$episode.m3u8',
      },
      '/api/ui/episode-engagement' => {
        'dramaId': 'episode-play-test',
        'episodeNumber': episode,
        'likes': 1000 + episode,
        'comments': 2000 + episode,
        'favorites': 3000 + episode,
        'shares': 4000 + episode,
      },
      '/api/ui/comments' => {'data': <Object?>[], 'total': 0},
      _ => {'ok': true},
    };
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(payload))),
      200,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _CountingVideoPlayerPlatform extends VideoPlayerPlatform {
  int _nextId = 1;
  final streams = <int, StreamController<VideoEvent>>{};
  int playCalls = 0;
  int pauseCalls = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    final id = _nextId++;
    final events = StreamController<VideoEvent>.broadcast();
    streams[id] = events;
    Timer.run(() {
      if (!events.isClosed) {
        events.add(
          VideoEvent(
            eventType: VideoEventType.initialized,
            duration: const Duration(seconds: 60),
            size: const Size(360, 640),
          ),
        );
      }
    });
    return id;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => streams[playerId]!.stream;

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> play(int playerId) async {
    playCalls++;
    streams[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ),
    );
  }

  @override
  Future<void> pause(int playerId) async {
    pauseCalls++;
    streams[playerId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: false,
      ),
    );
  }

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Future<void> dispose(int playerId) async {
    await streams.remove(playerId)?.close();
  }

  @override
  Widget buildView(int playerId) => const ColoredBox(color: Colors.black);
}

void main() {
  test('ranks five dramas by known play counts, not heat', () {
    const dramas = [
      Drama(id: 'a', title: 'A', views: '1.2万', heat: '1'),
      Drama(id: 'b', title: 'B', views: '9800', heat: '99亿'),
      Drama(id: 'c', title: 'C', views: '2.5万'),
      Drama(id: 'd', title: 'D', views: '11,200'),
      Drama(id: 'e', title: 'E', views: '8.1k'),
      Drama(id: 'f', title: 'F', views: '100'),
      Drama(id: 'unknown', title: '未知', views: 'unknown', heat: '100亿'),
    ];

    expect(buildMostViewedDramas(dramas).map((drama) => drama.id), [
      'c',
      'a',
      'd',
      'b',
      'e',
    ]);
  });

  testWidgets('samples at most ten dramas and opens details from the hero', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomePage(
            api: LibraryApi(
              client: _HomeCarouselClient(),
              playbackBaseUrl: 'http://playback.test',
            ),
            onSearch: _noop,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final carouselFinder = find.byKey(const ValueKey('home-featured-carousel'));
    expect(carouselFinder, findsOneWidget);
    final carousel = tester.widget<PageView>(carouselFinder);
    final carouselSize = tester.getSize(carouselFinder);
    expect(tester.getTopLeft(carouselFinder).dx, 0);
    expect(
      find.ancestor(of: carouselFinder, matching: find.byType(ClipRRect)),
      findsNothing,
    );
    expect(tester.getTopLeft(carouselFinder).dy, 0);
    expect(carouselSize.width, 375);
    expect(carouselSize.height, lessThan(400));
    expect(
      (carousel.childrenDelegate as SliverChildBuilderDelegate).childCount,
      10,
    );
    final homepageCard = find.ancestor(
      of: find.byKey(const ValueKey('drama-episode-count-badge-home-1')),
      matching: find.byType(DramaCard),
    );
    expect(homepageCard, findsOneWidget);
    expect(
      find.descendant(of: homepageCard, matching: find.text('2集')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: homepageCard, matching: find.text('finish · 2集')),
      findsNothing,
    );
    final poster = find
        .ancestor(
          of: find.byKey(const ValueKey('drama-episode-count-badge-home-1')),
          matching: find.byType(Stack),
        )
        .first;
    expect(
      tester
          .getRect(
            find.byKey(const ValueKey('drama-episode-count-badge-home-1')),
          )
          .left,
      closeTo(tester.getRect(poster).left + 8, .01),
    );
    expect(
      tester
          .getRect(
            find.byKey(const ValueKey('drama-episode-count-badge-home-1')),
          )
          .bottom,
      closeTo(tester.getRect(poster).bottom - 8, .01),
    );

    final firstTitle = tester
        .widget<Text>(find.byKey(const ValueKey('home-featured-title')))
        .data;
    await tester.tap(find.text('古装').first);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('home-featured-title')))
          .data,
      firstTitle,
    );

    final titleBeforeSwipe = tester
        .widget<Text>(find.byKey(const ValueKey('home-featured-title')))
        .data;
    await tester.drag(carouselFinder, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('home-featured-title')))
          .data,
      isNot(titleBeforeSwipe),
    );
    expect(
      find.byKey(const ValueKey('home-featured-poster-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('home-featured-poster-1')));
    await tester.pumpAndSettle();
    expect(find.byType(ShortDramaDetailsPage), findsOneWidget);
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    final miniPoster = find.byWidgetPredicate(
      (widget) =>
          widget is InkWell &&
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith(
            'home-featured-mini-poster-',
          ),
    );
    expect(miniPoster, findsNWidgets(2));
    await tester.tap(miniPoster.first);
    await tester.pumpAndSettle();
    expect(find.byType(ShortDramaDetailsPage), findsOneWidget);
  });

  testWidgets('keeps the home hero usable at large text on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Widget home(ThemeData theme) => MaterialApp(
      theme: theme,
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(375, 844),
          textScaler: TextScaler.linear(2),
        ),
        child: Scaffold(
          body: HomePage(api: LibraryApi(), onSearch: _noop, previewMode: true),
        ),
      ),
    );

    await tester.pumpWidget(home(ThemeData.light()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('搜索剧集'), findsOneWidget);
    final largeTextHeroHeight = tester
        .getSize(find.byKey(const ValueKey('home-featured-carousel')))
        .height;
    expect(largeTextHeroHeight, greaterThan(400));
    expect(largeTextHeroHeight, lessThan(460));

    await tester.pumpWidget(home(ThemeData.dark()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('搜索剧集'), findsOneWidget);
  });

  testWidgets('keeps the home layout scrollable in landscape', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const JuyouxiApp.preview());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey('home-featured-carousel')),
      findsOneWidget,
    );
    expect(find.byType(CustomScrollView), findsOneWidget);
  });

  testWidgets('hides release badges on home cards only', (tester) async {
    tester.view.physicalSize = const Size(375, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomePage(
            api: LibraryApi(client: _HomeCarouselClient()),
            onSearch: _noop,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
    await tester.pumpAndSettle();

    expect(find.text('finish'), findsNothing);
  });

  testWidgets(
    'keeps release badges enabled by default for shared drama cards',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: Center(
              child: SizedBox(
                width: 180,
                height: 260,
                child: DramaCard(
                  drama: const Drama(
                    id: 'search-result',
                    title: '搜索结果',
                    releaseStatus: 'finish',
                  ),
                  api: LibraryApi(),
                  onTap: _noop,
                ),
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('drama-release-status-badge')),
        findsOneWidget,
      );
    },
  );

  testWidgets('shows only a known episode count on opted-in cover cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: Center(
            child: SizedBox(
              width: 180,
              height: 260,
              child: DramaCard(
                drama: const Drama(
                  id: 'known-count',
                  title: '已知集数',
                  episodeCount: 12,
                  releaseStatus: 'finish',
                ),
                api: LibraryApi(),
                onTap: _noop,
                showEpisodeCountOnCover: true,
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('drama-episode-count-badge-known-count')),
      findsOneWidget,
    );
    expect(find.text('12集'), findsOneWidget);
    expect(find.text('finish · 12集'), findsNothing);
  });

  testWidgets('omits unknown and zero episode counts from cover cards', (
    tester,
  ) async {
    Widget card(Drama drama) => MaterialApp(
      home: Material(
        child: Center(
          child: SizedBox(
            width: 180,
            height: 260,
            child: DramaCard(
              drama: drama,
              api: LibraryApi(),
              onTap: _noop,
              showReleaseStatus: false,
              showEpisodeCountOnCover: true,
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      card(
        const Drama(
          id: 'unknown-count',
          title: '集数未知',
          releaseStatus: 'unknown',
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('drama-episode-count-badge-unknown-count')),
      findsNothing,
    );
    expect(find.text('unknown'), findsNothing);

    await tester.pumpWidget(
      card(const Drama(id: 'zero-count', title: '集数为零', episodeCount: 0)),
    );
    expect(
      find.byKey(const ValueKey('drama-episode-count-badge-zero-count')),
      findsNothing,
    );
  });

  testWidgets('opens a home drama in the immersive first episode page', (
    tester,
  ) async {
    await tester.pumpWidget(const JuyouxiApp.preview());

    expect(find.byKey(const ValueKey('home-featured-title')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-featured-poster-0')));
    await tester.pumpAndSettle();

    expect(find.text('短剧详情'), findsNothing);
    expect(find.text('第1集'), findsWidgets);
    expect(find.byTooltip('返回首页'), findsWidgets);
    expect(find.byType(NavigationBar), findsNothing);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('video-progress-touch-area')))
          .height,
      36,
    );
    expect(
      tester
          .getBottomLeft(find.byKey(const ValueKey('video-bottom-controls')))
          .dy,
      tester.getBottomLeft(find.byType(ShortDramaDetailsPage)).dy,
    );
    final detailControls = find.byKey(const ValueKey('video-bottom-controls'));
    final detailProgress = find.byKey(
      const ValueKey('video-progress-touch-area'),
    );
    final detailActions = find.byKey(const ValueKey('video-bottom-actions'));
    final detailSearch = find.byKey(const ValueKey('video-search-footer'));
    expect(detailSearch, findsOneWidget);
    expect(find.byTooltip('不喜欢'), findsOneWidget);
    expect(
      tester.getTopLeft(detailActions).dy -
          tester.getTopLeft(detailControls).dy,
      20,
    );
    expect(
      tester.getTopLeft(detailProgress).dy -
          tester.getBottomLeft(detailActions).dy,
      4,
    );
    expect(
      tester.getTopLeft(detailSearch).dy -
          tester.getBottomLeft(detailProgress).dy,
      -15,
    );
  });

  testWidgets('keeps the bottom tab bar visible on the video page', (
    tester,
  ) async {
    final systemUiModes = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
            systemUiModes.add(call.arguments as String);
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(const JuyouxiApp.preview());
    await tester.tap(find.text('视频'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(systemUiModes, contains(SystemUiMode.edgeToEdge.toString()));
    expect(
      systemUiModes,
      isNot(contains(SystemUiMode.immersiveSticky.toString())),
    );
  });

  testWidgets('renders the discovery video layout without losing controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const JuyouxiApp.preview());
    await tester.pumpAndSettle();
    await tester.tap(find.text('视频'));
    await tester.pumpAndSettle();

    expect(find.text('关注'), findsOneWidget);
    expect(find.text('直播'), findsNothing);
    expect(find.text('短剧'), findsOneWidget);
    expect(find.text('发现'), findsOneWidget);
    final channelGap =
        tester.getCenter(find.text('短剧')).dx -
        tester.getCenter(find.text('关注')).dx;
    expect(channelGap, closeTo(67.67, .1));
    expect(find.byTooltip('返回首页'), findsNothing);
    expect(find.byIcon(Icons.arrow_back_ios_new), findsNothing);
    expect(find.byTooltip('更多频道'), findsOneWidget);
    expect(find.byTooltip('搜剧'), findsOneWidget);
    expect(find.byKey(const ValueKey('video-search-footer')), findsOneWidget);
    expect(find.text('搜剧 · 预览短剧'), findsOneWidget);
    expect(find.byTooltip('不喜欢'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('video-search-footer'))).dy -
          tester
              .getBottomLeft(
                find.byKey(const ValueKey('video-progress-touch-area')),
              )
              .dy,
      -15,
    );
    expect(
      tester.getTopLeft(find.byIcon(Icons.heart_broken_outlined)).dy,
      tester.getTopLeft(find.byKey(const ValueKey('video-search-footer'))).dy,
    );
    expect(
      tester.getBottomLeft(find.text('不喜欢')).dy,
      tester
          .getBottomLeft(find.byKey(const ValueKey('video-search-footer')))
          .dy,
    );
    expect(
      tester.getBottomLeft(find.byIcon(Icons.heart_broken_outlined)).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.text('不喜欢')).dy),
    );
    expect(
      find.byKey(const ValueKey('video-progress-track-placeholder')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('video-bottom-actions')), findsOneWidget);
    expect(find.byTooltip('全屏'), findsOneWidget);
    expect(find.textContaining('免费观看'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.byTooltip('不喜欢'));
    await tester.pumpAndSettle();
    expect(find.text('不喜欢反馈暂未接入'), findsOneWidget);
  });

  testWidgets('keeps discovery bottom controls compact', (tester) async {
    tester.view.physicalSize = const Size(375, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const JuyouxiApp.preview());
    await tester.pumpAndSettle();
    await tester.tap(find.text('视频'));
    await tester.pumpAndSettle();

    final actions = find.byKey(const ValueKey('video-bottom-actions'));
    final progress = find.byKey(const ValueKey('video-progress-touch-area'));
    final search = find.byKey(const ValueKey('video-search-footer'));
    final description = find.byKey(const ValueKey('video-description-overlay'));
    final controls = find.byKey(const ValueKey('video-bottom-controls'));
    final viewportBottom = tester.getTopLeft(find.byType(NavigationBar)).dy;
    expect(tester.getBottomLeft(description).dy, viewportBottom - 136);
    expect(tester.getBottomLeft(controls).dy, viewportBottom);
    expect(
      tester.getBottomRight(find.text('不喜欢')).dy,
      lessThanOrEqualTo(viewportBottom),
    );
    expect(tester.getTopLeft(actions).dy - tester.getTopLeft(controls).dy, 20);
    expect(tester.getSize(actions).height, 44);
    expect(tester.getSize(progress).height, 36);
    expect(
      tester.getTopLeft(progress).dy - tester.getBottomLeft(actions).dy,
      4,
    );
    expect(
      tester
              .getTopLeft(
                find.byKey(const ValueKey('video-progress-track-placeholder')),
              )
              .dy -
          tester.getBottomLeft(actions).dy,
      10,
    );
    expect(
      tester.getTopLeft(search).dy - tester.getBottomLeft(progress).dy,
      -15,
    );

    expect(find.textContaining('免费观看'), findsOneWidget);
    expect(find.textContaining('倍速'), findsOneWidget);
    expect(find.byTooltip('全屏'), findsOneWidget);
    expect(find.text('搜剧 · 预览短剧'), findsOneWidget);
    expect(find.byTooltip('不喜欢'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('lets the video canvas extend behind the top safe area', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VideoFeedPage(
          api: LibraryApi(),
          active: true,
          previewMode: true,
          onExit: () {},
          onSearch: () {},
        ),
      ),
    );

    final safeAreas = tester.widgetList<SafeArea>(find.byType(SafeArea));
    expect(safeAreas.every((area) => !area.top), isTrue);
  });

  testWidgets('shows discovery channel controls without a fake episode title', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VideoFeedPage(
          api: LibraryApi(),
          active: true,
          previewMode: true,
          onExit: () {},
          onSearch: () {},
        ),
      ),
    );

    expect(find.byTooltip('返回首页'), findsNothing);
    expect(find.byTooltip('更多频道'), findsOneWidget);
    expect(find.text('第1集'), findsNothing);
    expect(find.text('搜剧'), findsNothing);
    expect(find.byTooltip('搜剧'), findsOneWidget);
    expect(find.byTooltip('游客资料'), findsNothing);
  });

  testWidgets('keeps the playback surface at y zero', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: 120)),
          child: VideoFeedPage(
            api: LibraryApi(),
            active: true,
            previewMode: true,
            onExit: () {},
            onSearch: () {},
          ),
        ),
      ),
    );

    expect(tester.getTopLeft(find.byType(VideoPlaybackSurface)).dy, 0);
  });

  testWidgets(
    'keeps the footer backdrop flush without obscuring the description',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(800, 600),
              padding: EdgeInsets.only(bottom: 48),
            ),
            child: VideoFeedPage(
              api: LibraryApi(),
              active: true,
              previewMode: true,
              onExit: () {},
              onSearch: () {},
            ),
          ),
        ),
      );

      final controlBackground = find.byWidgetPredicate(
        (widget) =>
            widget is Container && widget.color == Colors.black.withAlpha(230),
      );
      expect(tester.getBottomLeft(controlBackground).dy, 600);
      final description = find.byKey(
        const ValueKey('video-description-overlay'),
      );
      final actions = find.byKey(const ValueKey('video-bottom-actions'));
      expect(
        tester.getBottomLeft(description).dy,
        lessThanOrEqualTo(tester.getTopLeft(actions).dy),
      );

      const descriptionLayerKey = ValueKey('video-description-overlay');
      const controlsLayerKey = ValueKey('video-bottom-controls');
      final overlay = tester.widget<Stack>(
        find
            .ancestor(
              of: find.byKey(descriptionLayerKey),
              matching: find.byType(Stack),
            )
            .first,
      );
      int layerIndex(Key key) => overlay.children.indexWhere((child) {
        if (child is! Positioned) return false;
        final content = child.child;
        return content is KeyedSubtree && content.key == key;
      });
      final descriptionLayerIndex = layerIndex(descriptionLayerKey);
      final controlsLayerIndex = layerIndex(controlsLayerKey);
      expect(descriptionLayerIndex, greaterThan(controlsLayerIndex));
    },
  );

  testWidgets('anchors the video frame to the top of its viewport', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 320,
          height: 640,
          child: VideoFrame(
            size: Size(320, 180),
            child: ColoredBox(color: Colors.black),
          ),
        ),
      ),
    );

    final fittedBox = tester.widget<FittedBox>(find.byType(FittedBox));
    expect(fittedBox.alignment, Alignment.topCenter);
    expect(tester.getTopLeft(find.byType(FittedBox)).dy, 0);
  });

  testWidgets('keeps system UI visible while the video page is active', (
    tester,
  ) async {
    final systemUiModes = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
            systemUiModes.add(call.arguments as String);
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: VideoFeedPage(
          api: LibraryApi(),
          active: true,
          previewMode: true,
          onExit: () {},
          onSearch: () {},
        ),
      ),
    );
    await tester.pump();

    expect(systemUiModes, contains(SystemUiMode.edgeToEdge.toString()));
  });

  testWidgets('hides the system status bar on a direct drama details page', (
    tester,
  ) async {
    final systemUiModes = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
            systemUiModes.add(call.arguments as String);
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    const drama = Drama(
      id: 'preview-details',
      title: '预览短剧',
      category: '短剧',
      episodes: [Episode(number: 1, title: '第1集')],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ShortDramaDetailsPage(
          api: LibraryApi(),
          drama: drama,
          episodes: drama.episodes,
          initialEpisodeNumber: 1,
          onSearch: () {},
          previewMode: true,
        ),
      ),
    );
    await tester.pump();

    expect(systemUiModes, contains(SystemUiMode.immersiveSticky.toString()));
    expect(find.text('搜剧'), findsOneWidget);
    expect(find.byTooltip('游客资料'), findsOneWidget);
  });

  testWidgets(
    'episode picker keeps the current video playing and switching episodes starts playback',
    (tester) async {
      final previousPlatform = VideoPlayerPlatform.instance;
      final playerPlatform = _CountingVideoPlayerPlatform();
      VideoPlayerPlatform.instance = playerPlatform;
      addTearDown(() async {
        VideoPlayerPlatform.instance = previousPlatform;
        for (final stream in playerPlatform.streams.values) {
          if (!stream.isClosed) await stream.close();
        }
      });

      final client = _EpisodePlaybackClient();
      final api = LibraryApi(
        baseUrl: 'http://example.test',
        playbackBaseUrl: 'http://example.test',
        client: client,
      );
      addTearDown(client.close);
      await tester.pumpWidget(
        MaterialApp(
          home: ShortDramaDetailsPage(
            api: api,
            drama: const Drama(id: 'episode-play-test', title: '播放连续性测试剧'),
            episodes: const [
              Episode(number: 1, title: '第1集'),
              Episode(number: 2, title: '第2集'),
            ],
            initialEpisodeNumber: 1,
            onSearch: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(playerPlatform.playCalls, 1);

      final pausesBeforePicker = playerPlatform.pauseCalls;
      await tester.tap(find.textContaining('免费观看').last);
      await tester.pumpAndSettle();
      expect(find.byTooltip('关闭选集'), findsOneWidget);
      expect(playerPlatform.pauseCalls, pausesBeforePicker);

      await tester.tap(find.text('第2集').last);
      await tester.pumpAndSettle();
      expect(playerPlatform.playCalls, greaterThan(1));
    },
  );

  testWidgets(
    'renders dynamic category filters and primary navigation labels',
    (tester) async {
      await tester.pumpWidget(const JuyouxiApp.preview());

      expect(find.text('剧有戏'), findsOneWidget);
      expect(find.text('推荐'), findsOneWidget);
      expect(find.text('短剧'), findsWidgets);
      expect(find.text('追剧历史'), findsNothing);
      expect(find.text('精选榜'), findsNothing);
      expect(find.text('剧场'), findsNothing);
      expect(find.text('逆袭'), findsNothing);
      final categoryText = find.text('推荐').first;
      final categoryList = find
          .ancestor(of: categoryText, matching: find.byType(ListView))
          .first;
      final categoryTarget = find
          .ancestor(of: categoryText, matching: find.byType(InkWell))
          .first;
      expect(tester.getSize(categoryList).height, 56);
      expect(
        tester.getTopLeft(categoryList).dy -
            tester
                .getBottomLeft(
                  find.byKey(const ValueKey('home-featured-carousel')),
                )
                .dy,
        10,
      );
      expect(tester.getSize(categoryTarget).height, greaterThanOrEqualTo(48));
      final ongoingTitle = find.text('正在上演');
      expect(find.byKey(const ValueKey('home-ongoing-icon')), findsOneWidget);
      expect(
        tester.getTopLeft(ongoingTitle).dy -
            tester.getBottomLeft(categoryList).dy,
        lessThanOrEqualTo(10),
      );
      expect(find.text('首页'), findsOneWidget);
      expect(find.text('视频'), findsOneWidget);
      expect(find.text('搜索'), findsNothing);
      expect(find.text('追剧'), findsOneWidget);
      expect(find.text('我的'), findsOneWidget);
      expect(find.text('本集视频暂不可用'), findsNothing);
      expect(find.byType(VideoPlayer), findsNothing);

      await tester.tap(find.text('视频'));
      await tester.pump();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(ImageFiltered), findsOneWidget);
      expect(find.text('本集视频暂不可用'), findsOneWidget);

      await tester.tap(find.textContaining('免费观看'));
      await tester.pumpAndSettle();
      expect(find.text('短剧详情'), findsNothing);
      expect(find.byTooltip('返回首页'), findsWidgets);
      expect(find.textContaining('免费观看'), findsWidgets);
      expect(find.text('选集'), findsNothing);

      await tester.tap(find.textContaining('免费观看').last);
      await tester.pumpAndSettle();
      expect(find.text('选集'), findsOneWidget);
      expect(find.byType(GridView), findsOneWidget);
      expect(find.byTooltip('关闭选集'), findsOneWidget);
      expect(find.text('第1集'), findsWidgets);
      expect(find.text('第2集'), findsOneWidget);

      await tester.tap(find.text('第2集'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('点赞'), findsOneWidget);
      expect(find.byTooltip('收藏'), findsOneWidget);
      final likeCount = find.byKey(const ValueKey('video-action-like-count'));
      expect(likeCount, findsOneWidget);
      expect(tester.widget<Text>(likeCount).data, '0');
      await tester.tap(find.byTooltip('点赞'));
      await tester.tap(find.byTooltip('收藏'));
      await tester.pump();
      expect(find.byTooltip('取消点赞'), findsOneWidget);
      expect(find.byTooltip('取消收藏'), findsOneWidget);
      expect(tester.widget<Text>(likeCount).data, '1');
      final saveCount = find.byKey(const ValueKey('video-action-save-count'));
      expect(tester.widget<Text>(saveCount).data, '1');
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('video-action-comment-count')),
            )
            .data,
        '10',
      );

      await tester.tap(find.byTooltip('评论'));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.textContaining('10 条评论'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '很好看');
      await tester.pump();
      await tester.tap(find.byTooltip('发送评论'));
      await tester.pump();
      expect(find.text('很好看'), findsOneWidget);
      expect(find.textContaining('11 条评论'), findsOneWidget);
      await tester.tap(find.byTooltip('关闭评论'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('返回首页'));
      await tester.pump();
      expect(find.byType(NavigationBar), findsOneWidget);
    },
  );

  testWidgets('keeps the video action rail compact, white, and touchable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const JuyouxiApp.preview());
    await tester.pumpAndSettle();
    await tester.tap(find.text('视频'));
    await tester.pumpAndSettle();

    void expectCompactRail() {
      final tooltips = ['点赞', '评论', '收藏', '转发'];
      final buttons = <Finder>[];
      for (final tooltip in tooltips) {
        final button = find
            .ancestor(
              of: find.byTooltip(tooltip),
              matching: find.byType(IconButton),
            )
            .first;
        buttons.add(button);
        final icon = find
            .descendant(of: button, matching: find.byType(Icon))
            .first;
        expect(tester.widget<Icon>(icon).size, 32);
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
      }
      for (var index = 0; index < buttons.length - 1; index++) {
        expect(
          tester.getTopLeft(buttons[index + 1]).dy -
              tester.getBottomLeft(buttons[index]).dy,
          8,
        );
      }
      for (final key in [
        'video-action-like-count',
        'video-action-comment-count',
        'video-action-save-count',
        'video-action-share-count',
      ]) {
        expect(
          tester.widget<Text>(find.byKey(ValueKey(key))).style?.color,
          Colors.white,
        );
      }
      expect(
        tester
                .getTopLeft(find.byKey(const ValueKey('video-bottom-controls')))
                .dy -
            tester
                .getBottomLeft(find.byKey(const ValueKey('video-action-rail')))
                .dy,
        8,
      );
    }

    expectCompactRail();
    await tester.tap(find.textContaining('免费观看').first);
    await tester.pumpAndSettle();
    expectCompactRail();
  });

  testWidgets('uses compact comment spacing and keeps header controls apart', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const JuyouxiApp.preview());
    await tester.pumpAndSettle();
    await tester.tap(find.text('视频'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('评论'));
    await tester.pumpAndSettle();

    final title = tester.getRect(
      find.byKey(const ValueKey('video-comments-title')),
    );
    final expand = find.byTooltip('展开评论');
    final close = find.byTooltip('关闭评论');
    expect(title.overlaps(tester.getRect(expand)), isFalse);
    expect(title.overlaps(tester.getRect(close)), isFalse);
    expect(tester.getSize(expand).shortestSide, greaterThanOrEqualTo(44));
    expect(tester.getSize(close).shortestSide, greaterThanOrEqualTo(44));

    final firstRow = tester.widget<Padding>(
      find.byKey(const ValueKey('video-comment-row-preview-comment-1')),
    );
    expect(firstRow.padding, const EdgeInsets.symmetric(vertical: 4));
    expect(
      tester
          .getSize(find.byKey(const ValueKey('video-comment-divider-0')))
          .height,
      8,
    );
  });

  testWidgets('adds replies under a root comment without a third level', (
    tester,
  ) async {
    await tester.pumpWidget(const JuyouxiApp.preview());
    await tester.pumpAndSettle();
    await tester.tap(find.text('视频'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('评论'));
    await tester.pumpAndSettle();

    final composer = find.byKey(const ValueKey('video-comment-input'));
    expect(find.textContaining('条回复'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('video-comment-reply-preview-comment-1')),
    );
    expect(tester.widget<TextField>(composer).controller!.text, '@追剧小鱼 ');
    await tester.enterText(composer, '@追剧小鱼 第一条回复');
    await tester.pump();
    await tester.tap(find.byTooltip('发送评论'));
    await tester.pumpAndSettle();

    expect(find.textContaining('第一条回复'), findsOneWidget);
    expect(find.text('收起 1 条回复'), findsOneWidget);
    expect(find.textContaining('11 条评论'), findsOneWidget);
    expect(tester.widget<TextField>(composer).controller!.text, '');
    final firstReplyRow = find
        .ancestor(
          of: find.textContaining('第一条回复'),
          matching: find.byType(Padding),
        )
        .first;
    await tester.tap(
      find.descendant(of: firstReplyRow, matching: find.text('回复')),
    );
    expect(tester.widget<TextField>(composer).controller!.text, '@我 ');
    await tester.enterText(composer, '@我 第二条回复');
    await tester.pump();
    await tester.tap(find.byTooltip('发送评论'));
    await tester.pumpAndSettle();

    expect(find.textContaining('第二条回复'), findsOneWidget);
    expect(find.text('收起 2 条回复'), findsOneWidget);
    expect(find.textContaining('12 条评论'), findsOneWidget);
    expect(find.textContaining('展开 1 条回复'), findsNothing);
  });

  testWidgets('keeps loading progress visible in feed and drama details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(375, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const JuyouxiApp.preview());
    await tester.pumpAndSettle();
    await tester.tap(find.text('视频'));
    await tester.pumpAndSettle();

    final progressTrack = find.byKey(
      const ValueKey('video-progress-track-placeholder'),
    );
    expect(progressTrack, findsOneWidget);
    final aiAttribution = find.text('作者证明：内容由AI生成');
    expect(aiAttribution, findsOneWidget);
    expect(tester.widget<Text>(aiAttribution).style?.color, Colors.white30);
    final progressArea = find.byKey(
      const ValueKey('video-progress-touch-area'),
    );
    final actions = find.byKey(const ValueKey('video-bottom-actions'));
    final feedCommentCount = find.byKey(
      const ValueKey('video-action-comment-count'),
    );
    expect(tester.widget<Text>(feedCommentCount).data, '10');
    expect(
      tester.getTopLeft(progressArea).dy - tester.getBottomLeft(actions).dy,
      4,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('video-bottom-actions'))).dy -
          tester
              .getBottomLeft(
                find.byKey(const ValueKey('video-description-overlay')),
              )
              .dy,
      8,
    );

    await tester.tap(find.byTooltip('评论'));
    await tester.pumpAndSettle();
    expect(find.textContaining('10 条评论'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭评论'));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('免费观看').last);
    await tester.pumpAndSettle();
    expect(progressTrack, findsOneWidget);
    expect(aiAttribution, findsOneWidget);
    expect(find.byTooltip('评论'), findsOneWidget);
    expect(tester.widget<Text>(feedCommentCount).data, '10');
  });

  testWidgets('shows an accessible play button while the video is paused', (
    tester,
  ) async {
    final value = ValueNotifier(
      const VideoPlayerValue(
        duration: Duration(seconds: 1),
        isInitialized: true,
      ),
    );
    var playPressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: VideoPlayOverlay(
          valueListenable: value,
          onPlay: () => playPressed = true,
        ),
      ),
    );

    expect(find.byTooltip('播放视频'), findsOneWidget);
    await tester.tap(find.byTooltip('播放视频'));
    expect(playPressed, isTrue);

    value.value = value.value.copyWith(isPlaying: true);
    await tester.pump();
    expect(find.byTooltip('播放视频'), findsNothing);
  });

  testWidgets('pauses the video when the playback surface is tapped', (
    tester,
  ) async {
    final value = ValueNotifier(
      const VideoPlayerValue(
        duration: Duration(seconds: 1),
        isInitialized: true,
        isPlaying: true,
      ),
    );
    var pausePressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: VideoPlaybackSurface(
          valueListenable: value,
          onPlay: () {},
          onPause: () => pausePressed = true,
          child: const ColoredBox(color: Colors.black),
        ),
      ),
    );

    await tester.tapAt(const Offset(120, 120));
    expect(pausePressed, isTrue);
  });

  testWidgets('keeps the progress track visible before video is ready', (
    tester,
  ) async {
    Future<void> pumpProgressBar(
      ValueNotifier<VideoPlayerValue>? valueListenable,
    ) => tester.pumpWidget(
      MaterialApp(
        home: Material(
          color: Colors.black,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 320,
              child: VideoProgressBar(
                valueListenable: valueListenable,
                onSeek: (_) async {},
              ),
            ),
          ),
        ),
      ),
    );

    await pumpProgressBar(null);
    expect(
      find.byKey(const ValueKey('video-progress-track-placeholder')),
      findsOneWidget,
    );
    expect(find.byType(Slider), findsNothing);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('video-progress-touch-area')))
          .height,
      48,
    );

    final value = ValueNotifier(
      const VideoPlayerValue(duration: Duration.zero),
    );
    await pumpProgressBar(value);
    expect(
      find.byKey(const ValueKey('video-progress-track-placeholder')),
      findsOneWidget,
    );
    expect(find.byType(Slider), findsNothing);

    value.value = value.value.copyWith(
      duration: const Duration(seconds: 100),
      isInitialized: true,
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('video-progress-track-placeholder')),
      findsNothing,
    );
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('shows a draggable progress preview', (tester) async {
    final value = ValueNotifier(
      const VideoPlayerValue(
        duration: Duration(seconds: 100),
        position: Duration(seconds: 20),
        isInitialized: true,
      ),
    );
    final seeks = <Duration>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          color: Colors.black,
          child: SizedBox(
            width: 320,
            height: 120,
            child: Align(
              alignment: Alignment.topCenter,
              child: VideoProgressBar(
                valueListenable: value,
                posterUrl: null,
                fallbackUrl: null,
                onSeek: (position) async => seeks.add(position),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Slider), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('video-progress-touch-area')))
          .height,
      48,
    );
    final idleTheme = tester.widget<SliderTheme>(
      find.byKey(const ValueKey('video-progress-slider-theme')),
    );
    expect(idleTheme.data.trackHeight, 2);
    expect(idleTheme.data.padding, EdgeInsets.zero);
    expect(idleTheme.data.thumbShape, same(SliderComponentShape.noThumb));
    expect(find.byKey(const ValueKey('video-progress-preview')), findsNothing);

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Slider)),
    );
    await gesture.moveBy(const Offset(72, 0));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('video-progress-preview')),
      findsOneWidget,
    );
    final draggingTheme = tester.widget<SliderTheme>(
      find.byKey(const ValueKey('video-progress-slider-theme')),
    );
    expect(draggingTheme.data.trackHeight, 2);
    expect(draggingTheme.data.thumbShape, isA<RoundSliderThumbShape>());
    expect(seeks, isNotEmpty);

    await gesture.up();
    await tester.pump();
    expect(find.byKey(const ValueKey('video-progress-preview')), findsNothing);
  });

  testWidgets('shows current and total time while scrubbing', (tester) async {
    final value = ValueNotifier(
      const VideoPlayerValue(
        duration: Duration(seconds: 100),
        position: Duration(seconds: 20),
        isInitialized: true,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          color: Colors.black,
          child: SizedBox(
            width: 320,
            height: 120,
            child: Align(
              alignment: Alignment.topCenter,
              child: VideoProgressBar(
                valueListenable: value,
                compact: true,
                onSeek: (_) async {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      tester
          .getSize(find.byKey(const ValueKey('video-progress-touch-area')))
          .height,
      36,
    );
    final theme = tester.widget<SliderTheme>(
      find.byKey(const ValueKey('video-progress-slider-theme')),
    );
    final sliderBox = tester.renderObject<RenderBox>(find.byType(Slider));
    final trackRect = theme.data.trackShape!.getPreferredRect(
      parentBox: sliderBox,
      sliderTheme: theme.data,
      isEnabled: true,
      isDiscrete: false,
    );
    expect(trackRect.top, 6);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Slider)),
    );
    await gesture.moveBy(const Offset(72, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('00:59 / 01:40'), findsOneWidget);

    await gesture.up();
    await tester.pump();
    expect(find.text('00:59 / 01:40'), findsNothing);
  });

  test('builds category filters from drama data', () {
    final filters = buildCategoryFilters([
      const Drama(id: 'one', title: '一', category: '古装', tags: ['女频', '古装']),
      const Drama(id: 'two', title: '二', category: '古装', tags: ['逆袭']),
      const Drama(id: 'three', title: '三', category: '都市'),
    ]);

    expect(filters.first.label, '推荐');
    expect(filters.first.count, 3);
    expect(filters.skip(1).map((filter) => filter.label), [
      '古装',
      '女频',
      '逆袭',
      '都市',
    ]);
    expect(filters[1].count, 2);
    expect(filters[2].count, 1);
  });

  testWidgets('shows icons for the brand title and description', (
    tester,
  ) async {
    await tester.pumpWidget(const JuyouxiApp.preview());

    expect(find.byKey(const ValueKey('brand-title-icon')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('brand-description-icon')),
      findsOneWidget,
    );
  });

  testWidgets('extends the hero behind a transparent status bar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(top: 24)),
          child: Scaffold(
            body: HomePage(
              api: LibraryApi(),
              onSearch: _noop,
              previewMode: true,
            ),
          ),
        ),
      ),
    );

    final systemUi = tester
        .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byKey(const ValueKey('home-system-ui')),
        )
        .value;
    expect(systemUi.statusBarColor, Colors.transparent);
    expect(systemUi.statusBarIconBrightness, Brightness.light);
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('home-featured-carousel')))
          .dy,
      0,
    );
    expect(
      find.byKey(const ValueKey('home-status-bar-background')),
      findsNothing,
    );
  });

  testWidgets('opens the saved list from the reference following page', (
    tester,
  ) async {
    await tester.pumpWidget(const JuyouxiApp.preview());
    await tester.tap(find.text('追剧'));
    await tester.pumpAndSettle();

    expect(find.text('猜你在追'), findsOneWidget);
    expect(find.text('正在热播'), findsOneWidget);
    expect(find.text('暂无播放量数据'), findsOneWidget);
    await tester.tap(find.text('查看全部'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('following-count-summary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('following-search-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('following-filter-ongoing-count')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('following-filter-completed-count')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('following-filter-all-count')),
      findsOneWidget,
    );
    expect(find.text('追剧中'), findsWidgets);
    expect(find.text('已看完'), findsOneWidget);
    expect(find.text('全部'), findsOneWidget);
    expect(find.text('追剧样例'), findsOneWidget);
    expect(find.text('继续观看'), findsOneWidget);
    expect(find.text('看到第2集'), findsOneWidget);
    expect(find.text('共3集'), findsOneWidget);
    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const ValueKey('following-progress-preview-following')),
    );
    expect(progress.value, closeTo(2 / 3, 0.001));

    await tester.tap(find.text('已看完'));
    await tester.pump();
    expect(find.text('还没有追剧，去首页挑一部好戏吧'), findsOneWidget);
    await tester.tap(find.text('追剧中'));
    await tester.pump();

    await tester.tap(find.text('继续观看'));
    await tester.pumpAndSettle();
    expect(find.text('第2集'), findsWidgets);
  });

  testWidgets('uses playback history instead of known episode baseline', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FollowingPage(
            api: LibraryApi(
              baseUrl: 'http://test',
              client: _FollowingHistoryClient(),
            ),
            onSearch: _noop,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('查看全部'));
    await tester.pumpAndSettle();

    expect(find.text('看到第3集'), findsOneWidget);
    expect(find.text('看到第12集'), findsNothing);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const ValueKey('following-progress-history-drama')),
          )
          .value,
      closeTo(3 / 20, .001),
    );
  });

  testWidgets('refreshes today launches each time the following tab opens', (
    tester,
  ) async {
    final client = _FollowingRecommendationClient();
    final api = LibraryApi(baseUrl: 'http://test', client: client);
    Widget page(bool active) => MaterialApp(
      home: Scaffold(
        body: FollowingPage(
          key: const ValueKey('active-following-page'),
          api: api,
          onSearch: _noop,
          active: active,
        ),
      ),
    );

    await tester.pumpWidget(page(false));
    await tester.pumpAndSettle();
    expect(client.dramaRequests, 0);

    await tester.pumpWidget(page(true));
    await tester.pumpAndSettle();
    expect(client.dramaRequests, 1);

    await tester.pumpWidget(page(false));
    await tester.pumpWidget(page(true));
    await tester.pumpAndSettle();
    expect(client.dramaRequests, 2);
  });

  test('buildHotDramas sorts by heat with views fallback and caps at 150', () {
    final ranked = buildHotDramas([
      const Drama(id: 'low', title: '低', views: '90万', heat: '1万'),
      const Drama(id: 'tie-first', title: '并列一', views: '1', heat: '2万'),
      const Drama(
        id: 'unknown',
        title: '未知',
        views: 'unknown',
        heat: 'unknown',
      ),
      const Drama(id: 'tie-second', title: '并列二', views: '3', heat: '20000'),
      const Drama(id: 'fallback', title: '回退', views: '15000', heat: 'unknown'),
      const Drama(id: 'high', title: '高热', views: '1', heat: '3万'),
    ]);
    expect(ranked.map((drama) => drama.id), [
      'high',
      'tie-first',
      'tie-second',
      'fallback',
      'low',
      'unknown',
    ]);

    final capped = buildHotDramas([
      for (var index = 1; index <= 160; index++)
        Drama(id: 'cap-$index', title: '$index', views: '$index'),
    ]);
    expect(capped, hasLength(150));
    expect(capped.first.id, 'cap-160');
  });

  testWidgets('loads hot dramas in 15-item pages and stops after 10 pages', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FollowingPage(
            api: LibraryApi(
              baseUrl: 'http://test',
              client: _FollowingRecommendationClient(dramaCount: 160),
            ),
            onSearch: _noop,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollView = find.byType(CustomScrollView);
    SliverGrid hotGrid() => tester.widget<SliverGrid>(
      find.byKey(const ValueKey('following-hot-grid')),
    );
    expect(hotGrid().delegate.estimatedChildCount, 15);

    await tester.drag(scrollView, const Offset(0, -10000));
    await tester.pumpAndSettle();
    final firstPullCount = hotGrid().delegate.estimatedChildCount!;
    expect(firstPullCount, inInclusiveRange(30, 150));
    expect(firstPullCount % 15, 0);

    for (
      var page = 0;
      page < 10 && hotGrid().delegate.estimatedChildCount! < 150;
      page++
    ) {
      await tester.drag(scrollView, const Offset(0, -10000));
      await tester.pumpAndSettle();
    }
    expect(hotGrid().delegate.estimatedChildCount, 150);

    await tester.drag(scrollView, const Offset(0, -10000));
    await tester.pumpAndSettle();
    expect(hotGrid().delegate.estimatedChildCount, 150);
  });

  testWidgets('renders ranked hero and rail with the available hot catalog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FollowingPage(
            api: LibraryApi(
              baseUrl: 'http://test',
              client: _FollowingRecommendationClient(),
            ),
            onSearch: _noop,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('following-hero-rail')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('following-most-viewed-rail')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('following-hot-grid')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('following-hot-page-dot-0')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('following-hot-recommendation-page-view')),
      findsNothing,
    );
    final hotGrid = tester.widget<SliverGrid>(
      find.byKey(const ValueKey('following-hot-grid')),
    );
    expect(hotGrid.delegate.estimatedChildCount, 14);
    expect(
      find.byKey(const ValueKey('following-hero-drama-heat-14')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('following-most-viewed-heat-14')),
      findsOneWidget,
    );
    expect(find.text('14千次播放'), findsOneWidget);
  });

  testWidgets('opens a ranked poster in the existing details page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FollowingPage(
            api: LibraryApi(
              baseUrl: 'http://test',
              client: _FollowingRecommendationClient(),
            ),
            onSearch: _noop,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('following-hero-drama-heat-14')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ShortDramaDetailsPage), findsOneWidget);
  });

  testWidgets('profile status bar uses the header gradient', (tester) async {
    await tester.pumpWidget(const JuyouxiApp.preview());
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    final statusBackground = find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.key == const ValueKey('profile-status-bar-background'),
    );
    expect(statusBackground, findsOneWidget);
    final statusDecoration = tester.widget<DecoratedBox>(statusBackground);
    final heroDecoration = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('profile-hero')),
    );
    expect(
      (statusDecoration.decoration as BoxDecoration).gradient,
      same((heroDecoration.decoration as BoxDecoration).gradient),
    );

    final systemUi = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
      find.byKey(const ValueKey('profile-system-ui')),
    );
    expect(systemUi.value.statusBarColor, Colors.transparent);
  });

  testWidgets('renders the reference profile page', (tester) async {
    await tester.pumpWidget(const JuyouxiApp.preview());
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('profile-status-bar-background')),
      findsOneWidget,
    );
    expect(find.text('游客观众'), findsOneWidget);
    expect(find.text('成为VIP'), findsOneWidget);
    expect(find.text('我的消息'), findsOneWidget);
    expect(find.text('我的点赞'), findsOneWidget);
    expect(find.text('我的评论'), findsOneWidget);
    expect(find.text('最近看过'), findsOneWidget);
    expect(find.text('看剧偏好'), findsOneWidget);
    expect(find.text('邀请好友'), findsOneWidget);
    expect(find.text('上传视频'), findsOneWidget);
    expect(find.text('会员中心'), findsOneWidget);
    expect(find.text('关于剧有戏'), findsOneWidget);
  });

  testWidgets('keeps the recent-history title 15dp closer to my messages', (
    tester,
  ) async {
    await tester.pumpWidget(const JuyouxiApp.preview());
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    final messageBottom = tester.getBottomLeft(find.text('我的消息')).dy;
    final historyTitleTop = tester.getTopLeft(find.text('最近看过')).dy;
    expect(historyTitleTop - messageBottom, closeTo(28, 0.1));

    final quickActions = find.byKey(const ValueKey('profile-quick-actions'));
    expect(tester.getSize(quickActions).height, greaterThanOrEqualTo(64));
  });

  testWidgets('keeps the profile page compact without shrinking touch rows', (
    tester,
  ) async {
    await tester.pumpWidget(const JuyouxiApp.preview());
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const ValueKey('profile-hero'))).height,
      lessThanOrEqualTo(150),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('profile-history-card'))).height,
      lessThanOrEqualTo(225),
    );

    final quickActionsBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('profile-quick-actions')))
        .dy;
    final historyTop = tester
        .getTopLeft(find.byKey(const ValueKey('profile-history-card')))
        .dy;
    final historyBottom = tester
        .getBottomLeft(find.byKey(const ValueKey('profile-history-card')))
        .dy;
    final menuTop = tester
        .getTopLeft(find.byKey(const ValueKey('profile-menu-card')))
        .dy;
    expect(historyTop - quickActionsBottom, lessThanOrEqualTo(10));
    expect(menuTop - historyBottom, lessThanOrEqualTo(10));

    final menuRow = find.ancestor(
      of: find.text('看剧偏好'),
      matching: find.byType(ListTile),
    );
    expect(tester.getSize(menuRow).height, greaterThanOrEqualTo(48));
  });

  testWidgets('renders playback history returned by the API', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProfilePage(
          api: LibraryApi(client: _ProfileHistoryClient()),
          onOpenFollowing: () {},
          onSearch: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('观看记录测试剧'), findsOneWidget);
    expect(find.text('看到第3集'), findsOneWidget);
  });

  testWidgets('refreshes playback history when the profile tab opens', (
    tester,
  ) async {
    final client = _ProfileHistoryClient(hasHistory: false);
    await tester.pumpWidget(JuyouxiApp(api: LibraryApi(client: client)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    expect(find.text('暂无播放历史'), findsOneWidget);

    client.hasHistory = true;
    await tester.tap(find.text('首页'));
    await tester.pump();
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    expect(find.text('观看记录测试剧'), findsOneWidget);
    expect(find.text('看到第3集'), findsOneWidget);
  });

  testWidgets(
    'refreshes playback history when returning to a visible profile',
    (tester) async {
      final client = _ProfileHistoryClient();
      await tester.pumpWidget(JuyouxiApp(api: LibraryApi(client: client)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('我的'));
      await tester.pumpAndSettle();
      expect(find.text('观看记录测试剧'), findsOneWidget);

      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      final detailRoute = navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('临时详情页')),
        ),
      );
      await tester.pumpAndSettle();
      client.hasHistory = false;
      navigator.pop();
      await detailRoute;
      await tester.pumpAndSettle();

      expect(find.text('暂无播放历史'), findsOneWidget);
      expect(find.text('观看记录测试剧'), findsNothing);
    },
  );

  testWidgets('handles reference profile interactions', (tester) async {
    await tester.pumpWidget(const JuyouxiApp.preview());
    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile-history-more')));
    await tester.pumpAndSettle();
    expect(find.text('继续观看'), findsOneWidget);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('我的消息'));
    await tester.pump();
    expect(find.text('消息功能暂未开放'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('profile-scroll')),
      const Offset(0, -420),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('历史样例'));
    await tester.pumpAndSettle();
    expect(find.text('第2集'), findsWidgets);
  });

  test('recognizes AI dramas from their category or tags', () {
    expect(
      const Drama(
        id: 'ai-category',
        title: 'A',
        category: 'AI短剧',
      ).isAiGenerated,
      isTrue,
    );
    expect(
      const Drama(id: 'ai-tag', title: 'B', tags: ['AIGC']).isAiGenerated,
      isTrue,
    );
    expect(
      const Drama(id: 'regular', title: 'AI恋爱', category: '都市爱情').isAiGenerated,
      isFalse,
    );
    expect(
      Drama.fromJson({
        'id': 'ai-type-name',
        'title': 'C',
        'categoryName': '都市',
        'typeName': 'AIGC漫剧',
      }).isAiGenerated,
      isTrue,
    );
  });
}

void _noop() {}
