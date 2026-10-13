import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'library_api.dart';
import 'models.dart';

const _videoMuted = Color(0xFFD6D7DB);
const _videoContentDrop = 20.0;
const _previewComments = [
  DramaComment(
    id: 'preview-comment-1',
    dramaId: 'preview',
    authorName: '追剧小鱼',
    content: '开头节奏好快，一下子就看进去了。',
    likeCount: 14,
    isSeed: true,
  ),
  DramaComment(
    id: 'preview-comment-2',
    dramaId: 'preview',
    authorName: '橘子汽水',
    content: '男女主演得很自然，期待后面的反转。',
    likeCount: 1,
    isSeed: true,
  ),
  DramaComment(
    id: 'preview-comment-3',
    dramaId: 'preview',
    authorName: '晚风',
    content: '本来只想看一集，结果停不下来。',
    isSeed: true,
  ),
  DramaComment(
    id: 'preview-comment-4',
    dramaId: 'preview',
    authorName: '小月亮',
    content: '服化道挺用心的，画面也很舒服。',
    isSeed: true,
  ),
  DramaComment(
    id: 'preview-comment-5',
    dramaId: 'preview',
    authorName: '山茶花',
    content: '这段情绪拉满了，已经开始追更。',
    isSeed: true,
  ),
  DramaComment(
    id: 'preview-comment-6',
    dramaId: 'preview',
    authorName: '看剧的人',
    content: '剧情不拖沓，适合下班放松看。',
    isSeed: true,
  ),
  DramaComment(
    id: 'preview-comment-7',
    dramaId: 'preview',
    authorName: '云朵',
    content: '希望后面保持这个节奏，先收藏了。',
    isSeed: true,
  ),
  DramaComment(
    id: 'preview-comment-8',
    dramaId: 'preview',
    authorName: '星星糖',
    content: '配角也很出彩，几个人的互动好有趣。',
    isSeed: true,
  ),
  DramaComment(
    id: 'preview-comment-9',
    dramaId: 'preview',
    authorName: '小满',
    content: '这个设定有点意思，想知道接下来会怎样。',
    isSeed: true,
  ),
  DramaComment(
    id: 'preview-comment-10',
    dramaId: 'preview',
    authorName: '一颗葡萄',
    content: '最近难得看到这么轻松的短剧。',
    isSeed: true,
  ),
];

void _setVideoSystemUi(bool active) {
  SystemChrome.setEnabledSystemUIMode(
    active ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
  ).catchError((_) {});
}

class VideoFeedPage extends StatefulWidget {
  const VideoFeedPage({
    super.key,
    required this.api,
    this.active = false,
    required this.onExit,
    required this.onSearch,
    this.previewMode = false,
  });

  final LibraryApi api;
  final bool active;
  final VoidCallback onExit;
  final VoidCallback onSearch;
  final bool previewMode;

  @override
  State<VideoFeedPage> createState() => _VideoFeedPageState();
}

class _VideoFeedPageState extends State<VideoFeedPage> {
  final _pageController = PageController();
  List<Drama> _dramas = const [];
  bool _loading = false;
  String? _error;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.active) _setVideoSystemUi(false);
    if (widget.previewMode) {
      _dramas = const [
        Drama(
          id: 'preview',
          title: '预览短剧',
          category: 'AI短剧',
          episodes: [
            Episode(number: 1, title: '第1集'),
            Episode(number: 2, title: '第2集'),
            Episode(number: 3, title: '第3集'),
          ],
        ),
      ];
    } else if (widget.active) {
      _load();
    }
  }

  @override
  void didUpdateWidget(covariant VideoFeedPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _setVideoSystemUi(false);
    }
    if (!oldWidget.active && widget.active && !_loading && _dramas.isEmpty) {
      _load();
    }
  }

  @override
  void dispose() {
    if (widget.active) _setVideoSystemUi(false);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dramas = await widget.api.fetchDramas();
      if (mounted) setState(() => _dramas = dramas);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return const ColoredBox(color: Colors.black);
    }
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        top: false,
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _FeedError(message: _error!, onRetry: _load)
            : _dramas.isEmpty
            ? const _VideoUnavailable(
                title: '还没有可播放的短剧',
                detail: '剧库返回为空，稍后再来看看。',
              )
            : PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: _dramas.length,
                onPageChanged: (index) => setState(() => _currentIndex = index),
                itemBuilder: (context, index) {
                  return _VideoPage(
                    drama: _dramas[index],
                    api: widget.api,
                    active: widget.active && index == _currentIndex,
                    previewMode: widget.previewMode,
                    onExit: widget.onExit,
                    onSearch: widget.onSearch,
                  );
                },
              ),
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  const _VideoPage({
    required this.drama,
    required this.api,
    required this.active,
    required this.previewMode,
    required this.onExit,
    required this.onSearch,
    this.initialEpisode,
    this.onEpisodes,
  });

  final Drama drama;
  final LibraryApi api;
  final bool active;
  final bool previewMode;
  final VoidCallback onExit;
  final VoidCallback onSearch;
  final Episode? initialEpisode;
  final Future<void> Function()? onEpisodes;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  Future<void>? _initialization;
  Episode? _selectedEpisode;
  List<Episode> _episodes = const [];
  String? _playbackSession;
  String? _playbackError;
  bool _playbackLoading = false;
  int _playbackRequest = 0;
  double _speed = 1;
  bool _liked = false;
  bool _saved = false;
  List<DramaComment> _comments = const [];
  int _commentCount = 0;
  Episode? _engagementEpisode;
  Timer? _engagementRefreshTimer;
  bool _immersive = false;
  int? _reportedHistoryEpisode;

  Episode? get _episode => _selectedEpisode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedEpisode =
        widget.initialEpisode ??
        widget.drama.firstEpisode ??
        const Episode(number: 1, title: '第1集');
    if (widget.previewMode) {
      _comments = _previewComments;
      _commentCount = _previewComments.length;
    }
    if (widget.active) {
      _activate();
      _loadCommentCount();
      _startEngagementRefresh();
    }
  }

  @override
  void didUpdateWidget(covariant _VideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) return;
    if (widget.active) {
      _activate();
      _loadCommentCount();
      _startEngagementRefresh();
    } else {
      _stopEngagementRefresh();
      _releaseController();
      _closePlayback();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopEngagementRefresh();
    if (_immersive) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _controller?.dispose();
    _closePlayback();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _pauseForFocusLoss();
      _stopEngagementRefresh();
    } else if (widget.active) {
      _startEngagementRefresh();
    }
  }

  Future<void> _pausePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isPlaying) return;
    await controller.pause();
    if (mounted) setState(() {});
  }

  Future<void> _pauseForFocusLoss() => _pausePlayback();

  Future<void> _resumePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      await controller.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() => _playbackError = '视频播放失败，请稍后重试');
      }
    }
  }

  Future<void> _activate() async {
    if (!widget.active || _controller != null || _playbackLoading) return;
    final episode = _episode;
    if (episode == null) return;
    final request = ++_playbackRequest;
    if (episode.videoUrl != null) {
      await _startController(episode.videoUrl!, request);
      return;
    }
    if (widget.previewMode) return;
    if (mounted) {
      setState(() {
        _playbackLoading = true;
        _playbackError = null;
      });
    }
    try {
      var session = _playbackSession;
      if (session == null || session.isEmpty) {
        final opened = await widget.api.openPlayback(widget.drama.id);
        if (!mounted || request != _playbackRequest || !widget.active) {
          if (opened.session.isNotEmpty) {
            try {
              await widget.api.closePlayback(opened.session);
            } catch (_) {
              // A stale request must not keep a playback session alive.
            }
          }
          return;
        }
        session = opened.session;
        _playbackSession = session;
        _episodes = opened.episodes;
        Episode? selected;
        for (final item in _episodes) {
          if (item.number == _episode?.number) {
            selected = item;
            break;
          }
        }
        _selectedEpisode =
            selected ??
            (_episodes.isEmpty ? null : _episodes.first) ??
            _episode;
      }
      final activeEpisode = _episode;
      if (session.isEmpty || activeEpisode == null) {
        throw const ApiException('播放服务没有返回可播放分集', 502);
      }
      unawaited(_loadEpisodeEngagement(activeEpisode));
      for (final item in _episodes) {
        if (item.number == activeEpisode.number + 1) {
          unawaited(_loadEpisodeEngagement(item));
          break;
        }
      }
      final stream = await widget.api.openPlaybackStream(
        session,
        episode: activeEpisode.number,
      );
      if (!mounted || request != _playbackRequest || !widget.active) return;
      if (stream.url.isEmpty) {
        throw const ApiException('播放服务没有返回视频地址', 502);
      }
      await _startController(
        widget.api.playbackUrl(stream.url).toString(),
        request,
      );
    } catch (error) {
      if (mounted && request == _playbackRequest) {
        setState(() {
          _playbackError = error is ApiException
              ? error.message
              : '视频服务暂不可用，请稍后重试';
        });
      }
    } finally {
      if (mounted && request == _playbackRequest) {
        setState(() => _playbackLoading = false);
      }
    }
  }

  Future<void> _startController(String rawUrl, int request) async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(rawUrl));
    _controller = controller;
    _initialization = controller.initialize();
    if (mounted) setState(() {});
    try {
      await _initialization;
      if (!mounted || !widget.active || request != _playbackRequest) {
        controller.dispose();
        return;
      }
      await controller.setLooping(true);
      await controller.setPlaybackSpeed(_speed);
      await controller.play();
      unawaited(_recordPlaybackHistory(controller));
      if (mounted) setState(() {});
    } catch (_) {
      controller.dispose();
      if (mounted && request == _playbackRequest) {
        _controller = null;
        _initialization = null;
        setState(() => _playbackError = '视频加载失败，请稍后重试');
      }
    }
  }

  Future<void> _recordPlaybackHistory(VideoPlayerController controller) async {
    if (widget.previewMode) return;
    final episode = _episode;
    if (episode == null || _reportedHistoryEpisode == episode.number) return;
    _reportedHistoryEpisode = episode.number;
    try {
      final value = controller.value;
      await widget.api.recordPlaybackHistory(
        widget.drama.id,
        episodeNumber: episode.number,
        positionSeconds: value.position.inSeconds,
        durationSeconds: value.duration.inSeconds,
      );
    } catch (_) {
      // History is best effort and must not interrupt playback.
      if (_reportedHistoryEpisode == episode.number) {
        _reportedHistoryEpisode = null;
      }
    }
  }

  Future<void> _openDetails() async {
    final availableEpisodes = _episodes;
    final initialEpisodeNumber = _episode?.number ?? 1;
    _releaseController();
    await _closePlayback();
    if (!mounted) return;
    final selected = await Navigator.of(context).push<Episode>(
      MaterialPageRoute(
        builder: (_) => ShortDramaDetailsPage(
          api: widget.api,
          drama: widget.drama,
          episodes: availableEpisodes,
          initialEpisodeNumber: initialEpisodeNumber,
          onSearch: widget.onSearch,
          previewMode: widget.previewMode,
          restoreSystemUiOnDispose: false,
        ),
      ),
    );
    if (!mounted) return;
    if (selected == null) {
      if (widget.active) await _activate();
      return;
    }
    setState(() {
      _selectedEpisode = selected;
      _playbackError = null;
    });
    if (widget.active) await _activate();
  }

  Future<void> _openEpisodeControls() async {
    final inPagePicker = widget.onEpisodes;
    if (inPagePicker != null) {
      await inPagePicker();
      return;
    }
    await _pauseForFocusLoss();
    if (!mounted) return;
    await _openDetails();
  }

  void _openSearch() {
    _pauseForFocusLoss();
    widget.onSearch();
  }

  void _toggleLiked() => setState(() => _liked = !_liked);

  void _toggleSaved() => setState(() => _saved = !_saved);

  void _startEngagementRefresh() {
    _stopEngagementRefresh();
    if (!widget.active || widget.previewMode) return;
    final episode = _episode;
    if (episode != null) unawaited(_loadEpisodeEngagement(episode));
    _engagementRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      final episode = _episode;
      if (episode != null) unawaited(_loadEpisodeEngagement(episode));
    });
  }

  void _stopEngagementRefresh() {
    _engagementRefreshTimer?.cancel();
    _engagementRefreshTimer = null;
  }

  Future<void> _loadEpisodeEngagement(Episode episode) async {
    final dramaId = widget.drama.id;
    try {
      final counts = await widget.api.preloadEpisodeEngagement(
        dramaId,
        episode.number,
      );
      if (!mounted || !widget.active || widget.drama.id != dramaId) return;
      final updated = episode.copyWith(
        likes: counts.likes,
        comments: counts.comments,
        favorites: counts.favorites,
        shares: counts.shares,
      );
      setState(() {
        _episodes = [
          for (final item in _episodes)
            if (item.number == updated.number) updated else item,
        ];
        if (_episode?.number == updated.number) {
          _selectedEpisode = updated;
          _engagementEpisode = updated;
        }
      });
    } catch (_) {
      // Counts are optional; an unavailable endpoint must not delay playback.
    }
  }

  Future<void> _openComments() async {
    await _pauseForFocusLoss();
    if (!mounted) return;
    try {
      final page = widget.previewMode
          ? DramaComments(
              dramaId: widget.drama.id,
              data: _comments,
              total: _commentCount,
            )
          : await widget.api.fetchComments(widget.drama.id);
      if (!mounted) return;
      setState(() {
        _comments = page.data;
        _commentCount = page.total;
      });
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => _CommentSheet(
          initialComments: page.data,
          initialTotal: page.total,
          simulatedCommentHeat: _episode?.comments ?? 0,
          onSubmit: _submitComment,
          onTotalChanged: (total) {
            if (mounted) setState(() => _commentCount = total);
          },
        ),
      );
    } catch (error) {
      if (mounted) _showMessage(context, '评论加载失败：$error');
    }
  }

  Future<void> _loadCommentCount() async {
    if (widget.previewMode) return;
    try {
      final page = await widget.api.fetchComments(widget.drama.id);
      if (mounted) {
        setState(() {
          _comments = page.data;
          _commentCount = page.total;
        });
      }
    } catch (_) {
      // Keep the video playable if the optional comments service is offline.
    }
  }

  Future<CommentSubmission> _submitComment(
    String content, {
    String? parentId,
  }) async {
    if (!widget.previewMode) {
      return widget.api.submitComment(
        widget.drama.id,
        content,
        parentId: parentId,
      );
    }
    final comment = DramaComment(
      id: 'preview-user-${DateTime.now().microsecondsSinceEpoch}',
      dramaId: widget.drama.id,
      authorName: '我',
      content: content,
      parentId: parentId,
      createdAt: DateTime.now(),
    );
    var parentReplyCount = 0;
    final comments = [..._comments];
    if (parentId == null) {
      comments.insert(0, comment);
    } else {
      final parentIndex = comments.indexWhere((item) => item.id == parentId);
      if (parentIndex >= 0) {
        final parent = comments[parentIndex].copyWith(
          replyCount: comments[parentIndex].replyCount + 1,
        );
        comments[parentIndex] = parent;
        parentReplyCount = parent.replyCount;
        var insertIndex = parentIndex + 1;
        while (insertIndex < comments.length &&
            comments[insertIndex].parentId == parentId) {
          insertIndex++;
        }
        comments.insert(insertIndex, comment);
      }
    }
    setState(() => _comments = comments);
    return CommentSubmission(
      comment: comment,
      total: _commentCount + 1,
      parentReplyCount: parentId == null ? null : parentReplyCount,
    );
  }

  void _releaseController() {
    _playbackRequest++;
    final controller = _controller;
    _controller = null;
    _initialization = null;
    _playbackLoading = false;
    controller?.pause();
    controller?.dispose();
    if (mounted) setState(() {});
  }

  Future<void> _closePlayback() async {
    final session = _playbackSession;
    _playbackSession = null;
    _episodes = const [];
    if (session == null || session.isEmpty) return;
    try {
      await widget.api.closePlayback(session);
    } catch (_) {
      // Session cleanup is best effort when leaving the feed.
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _cycleSpeed() async {
    final double next = _speed == 1
        ? 1.5
        : _speed == 1.5
        ? 2
        : 1;
    setState(() => _speed = next);
    await _controller?.setPlaybackSpeed(next);
  }

  void _toggleImmersive() {
    setState(() => _immersive = !_immersive);
    SystemChrome.setEnabledSystemUIMode(
      _immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
    );
  }

  @override
  Widget build(BuildContext context) {
    final drama = widget.drama;
    final episode = _episode;
    final isFeedPage = widget.onEpisodes == null;
    final bottomInset = MediaQuery.paddingOf(context).bottom + 156;
    return Stack(
      fit: StackFit.expand,
      children: [
        VideoPlaybackSurface(
          valueListenable: _controller,
          onPlay: _resumePlayback,
          onPause: _pausePlayback,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _VideoCanvas(
                controller: _controller,
                initialization: _initialization,
                posterUrl: episode?.posterUrl,
                fallbackUrl: widget.api.coverUrl(drama),
              ),
              const _VideoShade(),
            ],
          ),
        ),
        if (widget.previewMode && episode?.videoUrl == null)
          const _VideoUnavailable(title: '本集视频暂不可用', detail: '当前剧集没有可播放的视频地址。'),
        if (_playbackLoading && _controller == null)
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        if (_playbackError != null)
          _VideoUnavailable(title: '视频暂不可用', detail: _playbackError!),
        if (isFeedPage)
          _FeedTopControls(
            onSearch: _openSearch,
            onUnavailable: () => _showMessage(context, '该频道暂未开放'),
          )
        else if (widget.onEpisodes != null)
          _TopControls(
            episodeNumber: episode?.number ?? 1,
            onExit: widget.onExit,
            onSearch: _openSearch,
            onProfile: () => _showMessage(context, '当前为游客模式'),
          ),
        Positioned(
          right: 8,
          bottom: bottomInset,
          child: _ActionRail(
            liked: _liked,
            saved: _saved,
            simulated:
                (_engagementEpisode?.number == episode?.number) &&
                ((_engagementEpisode?.likes ?? 0) > 0),
            likeCount: (episode?.likes ?? 0) + (_liked ? 1 : 0),
            commentCount: _commentCount + (episode?.comments ?? 0),
            saveCount: (episode?.favorites ?? 0) + (_saved ? 1 : 0),
            shareCount: episode?.shares ?? 0,
            onLike: _toggleLiked,
            onComment: _openComments,
            onSave: _toggleSaved,
            onShare: () => _showMessage(context, '分享链接暂不可用'),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: KeyedSubtree(
            key: const ValueKey('video-bottom-controls'),
            child: _BottomControls(
              drama: drama,
              controller: _controller,
              posterUrl: episode?.posterUrl,
              fallbackUrl: widget.api.coverUrl(drama),
              onSeek: (position) async {
                await _controller?.seekTo(position);
              },
              speed: _speed,
              onSpeed: _cycleSpeed,
              onFullscreen: _toggleImmersive,
              onEpisodes: _openEpisodeControls,
              dramaTitle: drama.title,
              onSearch: _openSearch,
              onDislike: () => _showMessage(context, '不喜欢反馈暂未接入'),
            ),
          ),
        ),
        Positioned(
          left: 16,
          right: 78,
          bottom: bottomInset - _videoContentDrop,
          child: KeyedSubtree(
            key: ValueKey('video-description-overlay'),
            child: _DramaOverlay(drama: drama, episode: episode),
          ),
        ),
      ],
    );
  }
}

class VideoFrame extends StatelessWidget {
  const VideoFrame({super.key, required this.size, required this.child});

  final Size size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        child: SizedBox(width: size.width, height: size.height, child: child),
      ),
    );
  }
}

class VideoProgressBar extends StatefulWidget {
  const VideoProgressBar({
    super.key,
    required this.valueListenable,
    required this.onSeek,
    this.posterUrl,
    this.fallbackUrl,
    this.compact = false,
  });

  final ValueListenable<VideoPlayerValue>? valueListenable;
  final Future<void> Function(Duration position) onSeek;
  final String? posterUrl;
  final Uri? fallbackUrl;
  final bool compact;

  @override
  State<VideoProgressBar> createState() => _VideoProgressBarState();
}

class _CompactVideoSliderTrackShape extends RoundedRectSliderTrackShape {
  const _CompactVideoSliderTrackShape();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) => super
      .getPreferredRect(
        parentBox: parentBox,
        offset: offset,
        sliderTheme: sliderTheme,
        isEnabled: isEnabled,
        isDiscrete: isDiscrete,
      )
      .shift(const Offset(0, -11));
}

class _VideoProgressBarState extends State<VideoProgressBar> {
  double? _dragProgress;
  bool _dragEndScheduled = false;

  @override
  Widget build(BuildContext context) {
    final listenable = widget.valueListenable;
    final touchAreaHeight = widget.compact ? 36.0 : 48.0;
    if (listenable == null) return _loadingTrack(touchAreaHeight);
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: listenable,
      builder: (context, value, _) {
        final duration = value.duration;
        if (!value.isInitialized || duration <= Duration.zero) {
          return _loadingTrack(touchAreaHeight);
        }
        final progress =
            (_dragProgress ??
                    value.position.inMilliseconds / duration.inMilliseconds)
                .clamp(0.0, 1.0)
                .toDouble();
        final previewing = _dragProgress != null;
        return LayoutBuilder(
          builder: (context, constraints) {
            const previewWidth = 112.0;
            final previewLeft =
                (progress * constraints.maxWidth - previewWidth / 2)
                    .clamp(
                      0.0,
                      (constraints.maxWidth - previewWidth).clamp(
                        0.0,
                        double.infinity,
                      ),
                    )
                    .toDouble();
            return Listener(
              behavior: HitTestBehavior.translucent,
              onPointerUp: (_) => _endDrag(),
              onPointerCancel: (_) => _endDrag(),
              child: SizedBox(
                // Keep the slider in one place while the preview appears above
                // it; changing the layout during a drag can cancel the gesture.
                key: const ValueKey('video-progress-touch-area'),
                height: touchAreaHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (previewing)
                      Positioned(
                        left: previewLeft,
                        top: -42,
                        child: _ProgressPreview(
                          key: const ValueKey('video-progress-preview'),
                          imageUrl:
                              widget.posterUrl ??
                              widget.fallbackUrl?.toString(),
                          position: _positionFor(progress, duration),
                          duration: duration,
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      height: touchAreaHeight,
                      bottom: 0,
                      child: SliderTheme(
                        key: const ValueKey('video-progress-slider-theme'),
                        data: SliderTheme.of(context).copyWith(
                          padding: EdgeInsets.zero,
                          trackHeight: 2,
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white38,
                          thumbColor: Colors.white,
                          overlayShape: previewing
                              ? const RoundSliderOverlayShape(overlayRadius: 14)
                              : SliderComponentShape.noOverlay,
                          thumbShape: previewing
                              ? const RoundSliderThumbShape(
                                  enabledThumbRadius: 5,
                                )
                              : SliderComponentShape.noThumb,
                          trackShape: widget.compact
                              ? const _CompactVideoSliderTrackShape()
                              : const RoundedRectSliderTrackShape(),
                        ),
                        child: Slider(
                          value: progress,
                          onChangeStart: (value) => setState(() {
                            _dragProgress = value;
                          }),
                          onChanged: (value) {
                            setState(() => _dragProgress = value);
                            widget.onSeek(_positionFor(value, duration));
                          },
                          onChangeEnd: (_) => _endDrag(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _loadingTrack(double height) {
    return SizedBox(
      key: const ValueKey('video-progress-touch-area'),
      height: height,
      child: Align(
        alignment: widget.compact ? Alignment.topCenter : Alignment.center,
        child: Padding(
          padding: EdgeInsets.only(top: widget.compact ? 6 : 0),
          child: const SizedBox(
            width: double.infinity,
            height: 2,
            child: DecoratedBox(
              key: ValueKey('video-progress-track-placeholder'),
              decoration: BoxDecoration(
                color: Colors.white38,
                borderRadius: BorderRadius.all(Radius.circular(1)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Duration _positionFor(double progress, Duration duration) {
    return Duration(milliseconds: (duration.inMilliseconds * progress).round());
  }

  void _endDrag() {
    if (!mounted || _dragProgress == null || _dragEndScheduled) return;
    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      setState(() => _dragProgress = null);
      return;
    }
    _dragEndScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dragEndScheduled = false;
      if (!mounted || _dragProgress == null) return;
      setState(() => _dragProgress = null);
    });
  }
}

class _ProgressPreview extends StatelessWidget {
  const _ProgressPreview({
    super.key,
    required this.imageUrl,
    required this.position,
    required this.duration,
  });

  final String? imageUrl;
  final Duration position;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 64,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white54),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null)
            Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const _PosterFallback(),
            )
          else
            const _PosterFallback(),
          Align(
            alignment: Alignment.bottomCenter,
            child: ColoredBox(
              color: Colors.black54,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  '${_formatVideoDuration(position)} / ${_formatVideoDuration(duration)}',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatVideoDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  final hours = duration.inHours;
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

class _VideoCanvas extends StatelessWidget {
  const _VideoCanvas({
    required this.controller,
    required this.initialization,
    required this.posterUrl,
    required this.fallbackUrl,
  });

  final VideoPlayerController? controller;
  final Future<void>? initialization;
  final String? posterUrl;
  final Uri? fallbackUrl;

  @override
  Widget build(BuildContext context) {
    final video = controller;
    final poster = posterUrl ?? fallbackUrl?.toString();
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Transform.scale(
            scale: 1.08,
            child: poster != null
                ? Image.network(
                    poster,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _PosterFallback(),
                  )
                : const _PosterFallback(),
          ),
        ),
        if (video != null && initialization != null)
          FutureBuilder<void>(
            future: initialization,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const _VideoUnavailable(
                  title: '视频加载失败',
                  detail: '当前视频暂时无法播放，请稍后重试。',
                );
              }
              if (snapshot.connectionState != ConnectionState.done ||
                  !video.value.isInitialized) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }
              final size = video.value.size;
              return VideoFrame(size: size, child: VideoPlayer(video));
            },
          ),
      ],
    );
  }
}

class VideoPlayOverlay extends StatelessWidget {
  const VideoPlayOverlay({
    super.key,
    required this.valueListenable,
    required this.onPlay,
  });

  final ValueListenable<VideoPlayerValue> valueListenable;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: valueListenable,
      builder: (context, value, child) {
        if (!value.isInitialized || value.isPlaying || value.isBuffering) {
          return const SizedBox.shrink();
        }
        return Center(
          child: Semantics(
            button: true,
            label: '播放视频',
            child: IconButton(
              onPressed: onPlay,
              tooltip: '播放视频',
              style: IconButton.styleFrom(
                minimumSize: const Size(64, 64),
                foregroundColor: Colors.white,
                backgroundColor: Colors.black.withAlpha(150),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 42),
            ),
          ),
        );
      },
    );
  }
}

class VideoPlaybackSurface extends StatelessWidget {
  const VideoPlaybackSurface({
    super.key,
    required this.valueListenable,
    required this.onPlay,
    required this.onPause,
    required this.child,
  });

  final ValueListenable<VideoPlayerValue>? valueListenable;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final listenable = valueListenable;
    if (listenable == null) return child;
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: listenable,
      builder: (context, value, _) {
        final canPause = value.isInitialized && value.isPlaying;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: canPause ? onPause : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              if (value.isInitialized && !value.isPlaying && !value.isBuffering)
                VideoPlayOverlay(valueListenable: listenable, onPlay: onPlay),
            ],
          ),
        );
      },
    );
  }
}

class _VideoShade extends StatelessWidget {
  const _VideoShade();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withAlpha(110),
              Colors.transparent,
              Colors.black.withAlpha(205),
            ],
            stops: const [0, .42, 1],
          ),
        ),
      ),
    );
  }
}

class _FeedTopControls extends StatelessWidget {
  const _FeedTopControls({required this.onSearch, required this.onUnavailable});

  final VoidCallback onSearch;
  final VoidCallback onUnavailable;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 8,
      right: 8,
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top + 6),
          child: Row(
            children: [
              IconButton(
                onPressed: onUnavailable,
                tooltip: '更多频道',
                style: IconButton.styleFrom(
                  minimumSize: const Size(36, 48),
                  padding: EdgeInsets.zero,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.menu, size: 25),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Row(
                    children: [
                      for (final label in const ['关注', '短剧', '发现'])
                        Expanded(
                          child: _FeedChannelTab(
                            label: label,
                            selected: label == '发现',
                            onTap: label == '发现' ? null : onUnavailable,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              IconButton(
                onPressed: onSearch,
                tooltip: '搜剧',
                style: IconButton.styleFrom(
                  minimumSize: const Size(36, 48),
                  padding: EdgeInsets.zero,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.search, size: 27),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedChannelTab extends StatelessWidget {
  const _FeedChannelTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white60,
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 5),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: selected ? 26 : 0,
                height: 2,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopControls extends StatelessWidget {
  const _TopControls({
    required this.episodeNumber,
    required this.onExit,
    required this.onSearch,
    required this.onProfile,
  });

  final int episodeNumber;
  final VoidCallback onExit;
  final VoidCallback onSearch;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.paddingOf(context).top + 8,
      left: 8,
      right: 8,
      child: Row(
        children: [
          IconButton(
            onPressed: onExit,
            tooltip: '返回首页',
            style: IconButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.arrow_back_ios_new),
          ),
          Text(
            '第$episodeNumber集',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onSearch,
            style: TextButton.styleFrom(
              minimumSize: const Size(92, 48),
              foregroundColor: Colors.white,
              backgroundColor: Colors.white.withAlpha(48),
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.search, size: 22),
            label: const Text('搜剧'),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onProfile,
            tooltip: '游客资料',
            style: IconButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.person_outline, size: 28),
          ),
        ],
      ),
    );
  }
}

class _ActionRail extends StatelessWidget {
  const _ActionRail({
    required this.liked,
    required this.saved,
    required this.simulated,
    required this.likeCount,
    required this.commentCount,
    required this.saveCount,
    required this.shareCount,
    required this.onLike,
    required this.onComment,
    required this.onSave,
    required this.onShare,
  });

  final bool liked;
  final bool saved;
  final bool simulated;
  final int likeCount;
  final int commentCount;
  final int saveCount;
  final int shareCount;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onSave;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('video-action-rail'),
      mainAxisSize: MainAxisSize.min,
      children: [
        if (simulated)
          const Padding(
            padding: EdgeInsets.only(bottom: 2),
            child: Text(
              '热度',
              style: TextStyle(
                color: Color(0xBFFFFFFF),
                fontSize: 10,
                height: 1.1,
              ),
            ),
          ),
        for (final (index, button) in [
          _RailButton(
            icon: liked ? Icons.favorite : Icons.favorite_border,
            label: liked ? '取消点赞' : '点赞',
            count: likeCount,
            countKey: const ValueKey('video-action-like-count'),
            color: liked ? const Color(0xFFFF4164) : Colors.white,
            onTap: onLike,
          ),
          _RailButton(
            icon: Icons.mode_comment,
            label: '评论',
            count: commentCount,
            countKey: const ValueKey('video-action-comment-count'),
            onTap: onComment,
          ),
          _RailButton(
            icon: saved ? Icons.star : Icons.star_border,
            label: saved ? '取消收藏' : '收藏',
            count: saveCount,
            countKey: const ValueKey('video-action-save-count'),
            onTap: onSave,
          ),
          _RailButton(
            icon: Icons.forward,
            label: '转发',
            count: shareCount,
            countKey: const ValueKey('video-action-share-count'),
            onTap: onShare,
          ),
        ].indexed) ...[if (index > 0) const SizedBox(height: 8), button],
      ],
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.countKey,
    required this.onTap,
    this.color = Colors.white,
  });

  final IconData icon;
  final String label;
  final int count;
  final Key countKey;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label，$count',
      child: IconButton(
        onPressed: onTap,
        tooltip: label,
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 56),
          padding: EdgeInsets.zero,
          foregroundColor: Colors.white,
        ),
        icon: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 2),
            Text(
              '$count',
              key: countKey,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DramaOverlay extends StatelessWidget {
  const _DramaOverlay({required this.drama, required this.episode});

  final Drama drama;
  final Episode? episode;

  @override
  Widget build(BuildContext context) {
    final category = drama.category.isEmpty ? '短剧' : drama.category;
    final episodeTitle = episode?.title ?? '第1集';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '短剧 · $category',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${drama.title}  $episodeTitle',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (drama.description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            drama.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _videoMuted, height: 1.35),
          ),
        ],
        if (drama.isAiGenerated) ...[
          const SizedBox(height: 6),
          const Text(
            '作者证明：内容由AI生成',
            style: TextStyle(color: Colors.white30, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.drama,
    required this.controller,
    required this.posterUrl,
    required this.fallbackUrl,
    required this.onSeek,
    required this.speed,
    required this.onSpeed,
    required this.onFullscreen,
    required this.onEpisodes,
    required this.dramaTitle,
    required this.onSearch,
    required this.onDislike,
  });

  final Drama drama;
  final ValueListenable<VideoPlayerValue>? controller;
  final String? posterUrl;
  final Uri? fallbackUrl;
  final Future<void> Function(Duration position) onSeek;
  final double speed;
  final VoidCallback onSpeed;
  final VoidCallback onFullscreen;
  final VoidCallback onEpisodes;
  final String dramaTitle;
  final VoidCallback onSearch;
  final VoidCallback onDislike;

  @override
  Widget build(BuildContext context) {
    final count =
        drama.episodeCount ??
        (drama.episodes.isEmpty ? null : drama.episodes.length);
    final episodeText = count == null ? '剧集信息待补充' : '共$count集';
    return Container(
      color: Colors.black.withAlpha(230),
      child: Transform.translate(
        offset: const Offset(0, _videoContentDrop),
        child: SafeArea(
          top: false,
          left: false,
          right: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  key: const ValueKey('video-bottom-actions'),
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: onEpisodes,
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 44),
                            padding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.play_circle_outline),
                          label: Text(
                            '$episodeText · 免费观看⌃',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: onSpeed,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(82, 44),
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: Colors.white,
                      ),
                      child: Text('${speed.toStringAsFixed(1)}倍速'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: onFullscreen,
                      tooltip: '全屏',
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 44),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.fullscreen),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: VideoProgressBar(
                  compact: true,
                  valueListenable: controller,
                  posterUrl: posterUrl,
                  fallbackUrl: fallbackUrl,
                  onSeek: onSeek,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Transform.translate(
                  offset: const Offset(0, -15),
                  child: _VideoSearchFooter(
                    dramaTitle: dramaTitle,
                    onSearch: onSearch,
                    onDislike: onDislike,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoSearchFooter extends StatelessWidget {
  const _VideoSearchFooter({
    required this.dramaTitle,
    required this.onSearch,
    required this.onDislike,
  });

  final String dramaTitle;
  final VoidCallback onSearch;
  final VoidCallback onDislike;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 4, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Material(
              color: const Color(0xFF191919),
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                key: const ValueKey('video-search-footer'),
                onTap: onSearch,
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 44,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '搜剧 · $dramaTitle',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 56,
            height: 44,
            child: Semantics(
              button: true,
              label: '不喜欢',
              child: Material(
                color: Colors.transparent,
                child: Tooltip(
                  message: '不喜欢',
                  child: InkWell(
                    onTap: onDislike,
                    borderRadius: BorderRadius.circular(22),
                    child: Stack(
                      children: [
                        const Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: Icon(
                            Icons.heart_broken_outlined,
                            color: Colors.white70,
                            size: 22,
                          ),
                        ),
                        const Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Text(
                            '不喜欢',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

List<Episode> _resolveEpisodeOptions(Drama drama, List<Episode> supplied) {
  if (supplied.isNotEmpty) return supplied;
  if (drama.episodes.isNotEmpty) return drama.episodes;
  final count = drama.episodeCount;
  if (count != null && count > 0) {
    return [
      for (var number = 1; number <= count; number++)
        Episode(number: number, title: '第$number集'),
    ];
  }
  return const [Episode(number: 1, title: '第1集')];
}

class ShortDramaDetailsPage extends StatefulWidget {
  const ShortDramaDetailsPage({
    super.key,
    required this.api,
    required this.drama,
    this.episodes = const [],
    required this.initialEpisodeNumber,
    required this.onSearch,
    this.previewMode = false,
    this.restoreSystemUiOnDispose = true,
  });

  final LibraryApi api;
  final Drama drama;
  final List<Episode> episodes;
  final int initialEpisodeNumber;
  final VoidCallback onSearch;
  final bool previewMode;
  final bool restoreSystemUiOnDispose;

  @override
  State<ShortDramaDetailsPage> createState() => _ShortDramaDetailsPageState();
}

class _ShortDramaDetailsPageState extends State<ShortDramaDetailsPage> {
  late final PageController _pageController;
  late final List<Episode> _availableEpisodes;
  late int _currentIndex;
  bool _openingPicker = false;

  @override
  void initState() {
    super.initState();
    _setVideoSystemUi(true);
    _availableEpisodes = _resolveEpisodeOptions(widget.drama, widget.episodes);
    _currentIndex = _availableEpisodes.indexWhere(
      (episode) => episode.number == widget.initialEpisodeNumber,
    );
    if (_currentIndex < 0) _currentIndex = 0;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    if (widget.restoreSystemUiOnDispose) _setVideoSystemUi(false);
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _openEpisodePicker() async {
    if (!mounted || _openingPicker) return;
    _openingPicker = true;
    final selected = await showModalBottomSheet<Episode>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _EpisodePicker(
        drama: widget.drama,
        episodes: _availableEpisodes,
        selectedNumber: _availableEpisodes[_currentIndex].number,
      ),
    );
    _openingPicker = false;
    if (!mounted || selected == null) return;
    final index = _availableEpisodes.indexWhere(
      (episode) => episode.number == selected.number,
    );
    if (index < 0 || index == _currentIndex) return;
    setState(() => _currentIndex = index);
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        top: false,
        bottom: false,
        child: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: _availableEpisodes.length,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          itemBuilder: (context, index) {
            return _VideoPage(
              drama: widget.drama,
              api: widget.api,
              active: index == _currentIndex,
              previewMode: widget.previewMode,
              initialEpisode: _availableEpisodes[index],
              onExit: () => Navigator.of(context).pop(),
              onSearch: widget.onSearch,
              onEpisodes: _openEpisodePicker,
            );
          },
        ),
      ),
    );
  }
}

class _EpisodePicker extends StatelessWidget {
  const _EpisodePicker({
    required this.drama,
    required this.episodes,
    required this.selectedNumber,
  });

  final Drama drama;
  final List<Episode> episodes;
  final int selectedNumber;

  @override
  Widget build(BuildContext context) {
    final availableEpisodes = _resolveEpisodeOptions(drama, episodes);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .72,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '选集',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF17181C),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: '关闭选集',
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: const Color(0xFF17181C),
                    ),
                  ),
                ],
              ),
              Text(
                drama.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF686C73)),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.only(bottom: 4),
                  itemCount: availableEpisodes.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.45,
                  ),
                  itemBuilder: (context, index) {
                    final episode = availableEpisodes[index];
                    final selected = episode.number == selectedNumber;
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: selected ? '${episode.title}，当前集' : episode.title,
                      child: Material(
                        color: selected
                            ? const Color(0xFF2F8CFF)
                            : const Color(0xFFF2F4F7),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(episode),
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  episode.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : const Color(0xFF17181C),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '在线播放',
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white.withAlpha(220)
                                        : const Color(0xFF686C73),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentSheet extends StatefulWidget {
  const _CommentSheet({
    required this.initialComments,
    required this.initialTotal,
    required this.simulatedCommentHeat,
    required this.onSubmit,
    required this.onTotalChanged,
  });

  final List<DramaComment> initialComments;
  final int initialTotal;
  final int simulatedCommentHeat;
  final Future<CommentSubmission> Function(String content, {String? parentId})
  onSubmit;
  final ValueChanged<int> onTotalChanged;

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  late final List<DramaComment> _comments = [...widget.initialComments];
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late int _total = widget.initialTotal;
  bool _expanded = false;
  bool _submitting = false;
  bool _hasText = false;
  String? _submitError;
  String? _replyParentId;
  final _likedComments = <String>{};
  final _expandedThreads = <String>{};

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _submitting) return;
    final parentId = _replyParentId;
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final result = await widget.onSubmit(text, parentId: parentId);
      if (!mounted) return;
      setState(() {
        if (parentId == null) {
          _comments.insert(0, result.comment);
        } else {
          final rootIndex = _comments.indexWhere(
            (comment) => comment.id == parentId,
          );
          if (rootIndex >= 0) {
            final root = _comments[rootIndex];
            _comments[rootIndex] = root.copyWith(
              replyCount: result.parentReplyCount ?? root.replyCount + 1,
            );
            var insertIndex = rootIndex + 1;
            while (insertIndex < _comments.length &&
                _comments[insertIndex].parentId == parentId) {
              insertIndex++;
            }
            _comments.insert(insertIndex, result.comment);
            _expandedThreads.add(parentId);
          } else {
            _comments.add(result.comment);
          }
        }
        _total = result.total;
        _controller.clear();
        _hasText = false;
        _replyParentId = null;
      });
      widget.onTotalChanged(_total);
    } catch (_) {
      if (mounted) setState(() => _submitError = '发送失败，请稍后重试');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roots = _comments
        .where(
          (comment) => comment.parentId == null || comment.parentId!.isEmpty,
        )
        .toList();
    return SafeArea(
      child: SizedBox(
        key: const ValueKey('video-comments-sheet'),
        height: MediaQuery.sizeOf(context).height * (_expanded ? .96 : .82),
        child: Column(
          children: [
            SizedBox(
              height: 54,
              child: Row(
                children: [
                  const SizedBox(width: 104),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$_total 条评论',
                            key: const ValueKey('video-comments-title'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF25272C),
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (widget.simulatedCommentHeat > 0)
                            Text(
                              '另有 ${widget.simulatedCommentHeat} 条模拟热度',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF8A8E96),
                                fontSize: 10,
                                height: 1.1,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 104,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          key: const ValueKey('video-comments-expand'),
                          onPressed: () =>
                              setState(() => _expanded = !_expanded),
                          tooltip: _expanded ? '收起评论' : '展开评论',
                          style: IconButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            backgroundColor: const Color(0xFFF4F5F6),
                            foregroundColor: const Color(0xFF25272C),
                          ),
                          icon: Icon(
                            _expanded
                                ? Icons.fullscreen_exit
                                : Icons.open_in_full,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          key: const ValueKey('video-comments-close'),
                          onPressed: () => Navigator.of(context).pop(),
                          tooltip: '关闭评论',
                          style: IconButton.styleFrom(
                            minimumSize: const Size(44, 44),
                            backgroundColor: const Color(0xFFF4F5F6),
                            foregroundColor: const Color(0xFF25272C),
                          ),
                          icon: const Icon(Icons.close, size: 21),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFECEDEF)),
            Expanded(
              child: _comments.isEmpty
                  ? const Center(
                      child: Text(
                        '还没有评论，来发第一条吧',
                        style: TextStyle(color: Color(0xFF8A8E96)),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(22, 12, 16, 16),
                      itemCount: roots.length,
                      separatorBuilder: (_, index) => SizedBox(
                        key: ValueKey('video-comment-divider-$index'),
                        height: 8,
                        child: const Divider(
                          height: 1,
                          indent: 64,
                          color: Color(0xFFF0F1F2),
                        ),
                      ),
                      itemBuilder: (context, index) {
                        final root = roots[index];
                        final replies = _comments
                            .where((comment) => comment.parentId == root.id)
                            .toList();
                        final expanded = _expandedThreads.contains(root.id);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _commentRow(root, index),
                            if (replies.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 64),
                                child: TextButton(
                                  key: ValueKey(
                                    'video-comment-thread-${root.id}',
                                  ),
                                  onPressed: () => setState(() {
                                    if (expanded) {
                                      _expandedThreads.remove(root.id);
                                    } else {
                                      _expandedThreads.add(root.id);
                                    }
                                  }),
                                  style: TextButton.styleFrom(
                                    minimumSize: const Size(44, 44),
                                    padding: EdgeInsets.zero,
                                    foregroundColor: const Color(0xFF5279B8),
                                  ),
                                  child: Text(
                                    '${expanded ? '收起' : '展开'} ${replies.length} 条回复',
                                  ),
                                ),
                              ),
                            if (expanded)
                              for (
                                var replyIndex = 0;
                                replyIndex < replies.length;
                                replyIndex++
                              ) ...[
                                if (replyIndex > 0) const SizedBox(height: 4),
                                _commentRow(
                                  replies[replyIndex],
                                  index + replyIndex + 1,
                                  isReply: true,
                                ),
                              ],
                          ],
                        );
                      },
                    ),
            ),
            if (_submitError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _submitError!,
                  style: const TextStyle(color: Color(0xFFBA1A1A)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 10),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F5),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('video-comment-input'),
                        controller: _controller,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.send,
                        onChanged: (value) =>
                            setState(() => _hasText = value.trim().isNotEmpty),
                        onSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(
                          hintText: '留下你的友善评论吧',
                          border: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.fromLTRB(18, 12, 4, 12),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {},
                      tooltip: '添加图片',
                      icon: const Icon(Icons.image_outlined),
                    ),
                    IconButton(
                      onPressed: () {},
                      tooltip: '提及好友',
                      icon: const Icon(Icons.alternate_email),
                    ),
                    IconButton(
                      onPressed: () {},
                      tooltip: '表情',
                      icon: const Icon(Icons.emoji_emotions_outlined),
                    ),
                    if (_hasText)
                      IconButton(
                        onPressed: _submitting ? null : _submit,
                        tooltip: '发送评论',
                        icon: _submitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_outlined),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _commentRow(DramaComment comment, int index, {bool isReply = false}) {
    final liked = _likedComments.contains(comment.id);
    return Padding(
      key: ValueKey('video-comment-row-${comment.id}'),
      padding: EdgeInsets.symmetric(vertical: isReply ? 3 : 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isReply) const SizedBox(width: 36),
          CircleAvatar(
            radius: isReply ? 16 : 21,
            backgroundColor: index.isEven
                ? const Color(0xFFEAF1FF)
                : const Color(0xFFF2EAFE),
            foregroundColor: const Color(0xFF68738B),
            child: Icon(Icons.person, size: isReply ? 18 : 23),
          ),
          SizedBox(width: isReply ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comment.authorName,
                  style: const TextStyle(
                    color: Color(0xFF969AA1),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: const TextStyle(
                    color: Color(0xFF303238),
                    fontSize: 16,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _commentTime(comment.createdAt),
                      style: const TextStyle(
                        color: Color(0xFFA7AAB0),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      key: ValueKey('video-comment-reply-${comment.id}'),
                      onPressed: () => _replyTo(comment),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        padding: EdgeInsets.zero,
                        foregroundColor: const Color(0xFF8E9299),
                      ),
                      child: const Text('回复'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            width: 48,
            child: Column(
              children: [
                IconButton(
                  onPressed: () => setState(() {
                    if (liked) {
                      _likedComments.remove(comment.id);
                    } else {
                      _likedComments.add(comment.id);
                    }
                  }),
                  tooltip: '赞评论',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    foregroundColor: liked
                        ? const Color(0xFFED5B70)
                        : const Color(0xFF9A9EA4),
                  ),
                  icon: Icon(
                    liked ? Icons.favorite : Icons.favorite_border,
                    size: 20,
                  ),
                ),
                Text(
                  '${comment.likeCount + (liked ? 1 : 0)}',
                  style: const TextStyle(
                    color: Color(0xFF9A9EA4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _replyTo(DramaComment comment) {
    final parentId = comment.parentId ?? comment.id;
    _controller.text = '@${comment.authorName} ';
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    setState(() {
      _replyParentId = parentId;
      _hasText = true;
    });
    _focusNode.requestFocus();
  }

  String _commentTime(DateTime? createdAt) {
    if (createdAt == null) return '刚刚';
    final minutes = DateTime.now().difference(createdAt).inMinutes;
    if (minutes < 1) return '刚刚';
    if (minutes < 60) return '$minutes分钟前';
    final hours = (minutes / 60).floor();
    if (hours < 24) return '$hours小时前';
    return '${(hours / 24).floor()}天前';
  }
}

class _PosterFallback extends StatelessWidget {
  const _PosterFallback();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF15171B),
      child: Center(
        child: Icon(
          Icons.movie_outlined,
          color: Colors.white.withAlpha(90),
          size: 54,
        ),
      ),
    );
  }
}

class _VideoUnavailable extends StatelessWidget {
  const _VideoUnavailable({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off_outlined,
              color: _videoMuted,
              size: 44,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _videoMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedError extends StatelessWidget {
  const _FeedError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_outlined, color: _videoMuted, size: 44),
            const SizedBox(height: 14),
            const Text(
              '视频剧库暂时没有响应',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _videoMuted),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
