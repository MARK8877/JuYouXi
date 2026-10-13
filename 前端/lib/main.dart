import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/drama_widgets.dart';
import 'src/library_api.dart';
import 'src/models.dart';
import 'src/video_feed.dart';

const _ink = Color(0xFF17181C);
const _stageWhite = Color(0xFFF6F7F9);
const _vermilion = Color(0xFFC93B32);
const _ticketGold = Color(0xFFD5A548);
const _muted = Color(0xFF686C73);
const _profileHeaderTop = Color(0xFF20242A);
const _profileHeaderBottom = Color(0xFF8E856E);
const _profileHeaderGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [_profileHeaderTop, _profileHeaderBottom],
);
const _profileVip = Color(0xFFF35B73);
const _followingBackground = Color(0xFF171719);
const _followingSurface = Color(0xFF252529);
const _followingSecondary = Color(0xFFA4A4AA);
const _followingAccent = Color(0xFFF12F62);
final _pageRouteObserver = RouteObserver<PageRoute<dynamic>>();

class CategoryFilter {
  const CategoryFilter({required this.label, required this.count});

  final String label;
  final int count;
}

List<CategoryFilter> buildCategoryFilters(Iterable<Drama> dramas) {
  final items = dramas.toList(growable: false);
  final counts = <String, int>{};
  for (final drama in items) {
    final labels = <String>{};
    final category = drama.category.trim();
    if (category.isNotEmpty && category != '推荐') labels.add(category);
    for (final tag in drama.tags) {
      final value = tag.trim();
      if (value.isNotEmpty && value != '推荐') labels.add(value);
    }
    for (final label in labels) {
      counts[label] = (counts[label] ?? 0) + 1;
    }
  }
  return [
    CategoryFilter(label: '推荐', count: items.length),
    for (final entry in counts.entries)
      CategoryFilter(label: entry.key, count: entry.value),
  ];
}

List<Drama> buildTopHeatRecommendations(Iterable<Drama> dramas) {
  final ranked = <({Drama drama, double heat, int order})>[];
  var order = 0;
  for (final drama in dramas) {
    final heat = _parseHeat(drama.heat);
    if (heat != null) ranked.add((drama: drama, heat: heat, order: order));
    order++;
  }
  ranked.sort((a, b) {
    final byHeat = b.heat.compareTo(a.heat);
    return byHeat != 0 ? byHeat : a.order.compareTo(b.order);
  });
  return ranked.take(12).map((item) => item.drama).toList(growable: false);
}

List<Drama> buildMostViewedDramas(Iterable<Drama> dramas) {
  final ranked = <({Drama drama, double views, int order})>[];
  var order = 0;
  for (final drama in dramas) {
    final views = _parseHeat(drama.views);
    if (views != null) ranked.add((drama: drama, views: views, order: order));
    order++;
  }
  ranked.sort((a, b) {
    final byViews = b.views.compareTo(a.views);
    return byViews != 0 ? byViews : a.order.compareTo(b.order);
  });
  return ranked.take(5).map((item) => item.drama).toList(growable: false);
}

List<Drama> buildHotDramas(Iterable<Drama> dramas) {
  final ranked = <({Drama drama, double heat, int order})>[];
  final seen = <String>{};
  var order = 0;
  for (final drama in dramas) {
    if (seen.add(drama.id)) {
      ranked.add((
        drama: drama,
        heat: _parseHeat(drama.heat) ?? _parseHeat(drama.views) ?? 0,
        order: order,
      ));
      order++;
    }
  }
  ranked.sort((a, b) {
    final byHeat = b.heat.compareTo(a.heat);
    return byHeat != 0 ? byHeat : a.order.compareTo(b.order);
  });
  return ranked.take(150).map((item) => item.drama).toList(growable: false);
}

String formatPlayCount(String value) {
  final views = _parseHeat(value);
  if (views == null) return '播放量未知';
  final thousands = (views / 1000).toStringAsFixed(3);
  final compact = thousands
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  return '$compact千次播放';
}

double? _parseHeat(String value) {
  final trimmed = value.trim();
  final numberText = RegExp(r'[\d,.]+').firstMatch(trimmed)?.group(0);
  final number = double.tryParse(numberText?.replaceAll(',', '') ?? '');
  if (number == null || !number.isFinite) return null;
  final normalized = trimmed.toLowerCase();
  final multiplier = normalized.contains('亿')
      ? 100000000.0
      : normalized.contains('万') || normalized.contains('w')
      ? 10000.0
      : normalized.contains('k')
      ? 1000.0
      : 1.0;
  final heat = number * multiplier;
  return heat.isFinite ? heat : null;
}

void main() {
  runApp(JuyouxiApp(api: LibraryApi()));
}

class JuyouxiApp extends StatelessWidget {
  const JuyouxiApp({super.key, required this.api, this.previewMode = false});

  const JuyouxiApp.preview({super.key}) : api = null, previewMode = true;

  final LibraryApi? api;
  final bool previewMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '剧有戏',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [_pageRouteObserver],
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: AppShell(api: api ?? LibraryApi(), previewMode: previewMode),
    );
  }
}

ThemeData _theme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: dark ? const Color(0xFFFF786B) : _vermilion,
    onPrimary: Colors.white,
    secondary: dark ? const Color(0xFFE9C66A) : _ticketGold,
    onSecondary: _ink,
    error: const Color(0xFFBA1A1A),
    onError: Colors.white,
    surface: dark ? const Color(0xFF202124) : _stageWhite,
    onSurface: dark ? const Color(0xFFF2F2F2) : _ink,
    surfaceContainerHighest: dark ? const Color(0xFF303136) : Colors.white,
    onSurfaceVariant: dark ? const Color(0xFFC5C6CC) : _muted,
    outline: dark ? const Color(0xFF8E9098) : const Color(0xFFD9DCE2),
  );
  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    useMaterial3: true,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? const Color(0xFF191A1D) : Colors.white,
      indicatorColor: dark ? const Color(0xFF5D2724) : const Color(0xFFFFE1DE),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF303136) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.api, this.previewMode = false});

  final LibraryApi api;
  final bool previewMode;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;
  bool _followingCollectionRequested = false;

  @override
  Widget build(BuildContext context) {
    final videoSelected = _selectedIndex == 1;
    final followingSelected = _selectedIndex == 2;
    final pages = [
      HomePage(
        api: widget.api,
        previewMode: widget.previewMode,
        onSearch: _openSearch,
      ),
      VideoFeedPage(
        api: widget.api,
        active: videoSelected,
        previewMode: widget.previewMode,
        onExit: () => setState(() => _selectedIndex = 0),
        onSearch: _openSearch,
      ),
      FollowingPage(
        api: widget.api,
        onSearch: _openSearch,
        previewMode: widget.previewMode,
        openCollection: _followingCollectionRequested,
        active: followingSelected,
      ),
      ProfilePage(
        api: widget.api,
        active: _selectedIndex == 3,
        previewMode: widget.previewMode,
        onSearch: _openSearch,
        onOpenFollowing: () => setState(() {
          _followingCollectionRequested = true;
          _selectedIndex = 2;
        }),
      ),
    ];
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBarTheme(
        data: followingSelected
            ? const NavigationBarThemeData(
                backgroundColor: _followingBackground,
                indicatorColor: _followingSurface,
                labelTextStyle: WidgetStatePropertyAll(
                  TextStyle(color: Colors.white, fontSize: 12),
                ),
                iconTheme: WidgetStatePropertyAll(
                  IconThemeData(color: Colors.white),
                ),
              )
            : Theme.of(context).navigationBarTheme,
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) => setState(() {
            _selectedIndex = index;
            if (index == 2) _followingCollectionRequested = false;
          }),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.theaters_outlined),
              selectedIcon: Icon(Icons.theaters),
              label: '首页',
            ),
            NavigationDestination(
              icon: Icon(Icons.smart_display_outlined),
              selectedIcon: Icon(Icons.smart_display),
              label: '视频',
            ),
            NavigationDestination(
              icon: Icon(Icons.bookmark_border),
              selectedIcon: Icon(Icons.bookmark),
              label: '追剧',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }

  void _openSearch() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .84,
        child: SearchPage(
          api: widget.api,
          onSearch: _openSearch,
          previewMode: widget.previewMode,
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.api,
    required this.onSearch,
    this.previewMode = false,
  });

  final LibraryApi api;
  final VoidCallback onSearch;
  final bool previewMode;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Drama> _dramas = const [];
  List<Drama> _featuredDramas = const [];
  String _category = '推荐';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.previewMode) {
      _dramas = const [
        Drama(
          id: 'preview-home',
          title: '预览短剧',
          category: '短剧',
          episodeCount: 3,
          episodes: [
            Episode(number: 1, title: '第1集'),
            Episode(number: 2, title: '第2集'),
            Episode(number: 3, title: '第3集'),
          ],
        ),
      ];
      _featuredDramas = _dramas;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dramas = await widget.api.fetchDramas();
      if (!mounted) return;
      setState(() {
        _dramas = dramas;
        _featuredDramas = _pickFeaturedDramas(dramas);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = buildCategoryFilters(_dramas);
    final heroBaseHeight = (MediaQuery.sizeOf(context).height * .42)
        .clamp(340.0, 440.0)
        .toDouble();
    final heroTextScale = MediaQuery.textScalerOf(context).scale(26) / 26;
    final heroHeight =
        heroBaseHeight + (heroTextScale > 1 ? (heroTextScale - 1) * 80 : 0);
    final topInset = MediaQuery.paddingOf(context).top;
    final selectedCategory =
        categories.any((filter) => filter.label == _category)
        ? _category
        : categories.first.label;
    final visible = selectedCategory == '推荐'
        ? _dramas
        : _dramas
              .where(
                (drama) =>
                    drama.category.trim() == selectedCategory ||
                    drama.tags.any((tag) => tag.trim() == selectedCategory),
              )
              .toList();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      key: const ValueKey('home-system-ui'),
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Stack(
        children: [
          SafeArea(
            top: false,
            child: RefreshIndicator(
              onRefresh: widget.previewMode ? () async {} : _load,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _HomeHero(
                      dramas: _featuredDramas,
                      api: widget.api,
                      onSearch: widget.onSearch,
                      onOpen: (drama) => _showDetails(context, drama),
                      height: heroHeight + topInset + 8,
                      topInset: topInset + 8,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _CategoryRail(
                        categories: categories,
                        selected: selectedCategory,
                        onSelected: (category) =>
                            setState(() => _category = category),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const ExcludeSemantics(
                            child: Icon(
                              Icons.play_circle_fill_rounded,
                              key: ValueKey('home-ongoing-icon'),
                              color: _vermilion,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '正在上演',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const Spacer(),
                          Text(
                            '${visible.length} 部',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: _muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_loading)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_error != null)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _ErrorState(message: _error!, onRetry: _load),
                    )
                  else if (visible.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptyState(message: '剧库还没有内容'),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.crossAxisExtent >= 900
                              ? 5
                              : constraints.crossAxisExtent >= 600
                              ? 4
                              : 3;
                          return SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => DramaCard(
                                drama: visible[index],
                                api: widget.api,
                                showReleaseStatus: false,
                                showEpisodeCountOnCover: true,
                                onTap: () =>
                                    _showDetails(context, visible[index]),
                              ),
                              childCount: visible.length,
                            ),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 18,
                                  childAspectRatio: columns == 3 ? .59 : .62,
                                ),
                          );
                        },
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Drama> _pickFeaturedDramas(List<Drama> dramas) {
    final ids = <String>{};
    final unique = dramas.where((drama) => ids.add(drama.id)).toList()
      ..shuffle();
    return unique.take(10).toList(growable: false);
  }

  void _showDetails(BuildContext context, Drama drama) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ShortDramaDetailsPage(
          api: widget.api,
          drama: drama,
          episodes: drama.episodes,
          initialEpisodeNumber: drama.firstEpisode?.number ?? 1,
          onSearch: widget.onSearch,
          previewMode: widget.previewMode,
        ),
      ),
    );
  }
}

class _HomeHero extends StatefulWidget {
  const _HomeHero({
    required this.dramas,
    required this.api,
    required this.onSearch,
    required this.onOpen,
    required this.height,
    required this.topInset,
  });

  final List<Drama> dramas;
  final LibraryApi api;
  final VoidCallback onSearch;
  final ValueChanged<Drama> onOpen;
  final double height;
  final double topInset;

  @override
  State<_HomeHero> createState() => _HomeHeroState();
}

class _HomeHeroState extends State<_HomeHero> {
  final _pageController = PageController();
  int _currentIndex = 0;

  @override
  void didUpdateWidget(covariant _HomeHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dramas != widget.dramas) {
      _currentIndex = 0;
      if (_pageController.hasClients) _pageController.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final drama = widget.dramas.isEmpty ? null : widget.dramas[_currentIndex];
    final episodeLabel = drama == null
        ? ''
        : drama.episodeLabel.replaceFirst(
            RegExp(r'^finished(?=\s|$)', caseSensitive: false),
            '大结局',
          );
    final miniDramas = drama == null
        ? const <Drama>[]
        : [
            for (
              var offset = 1;
              offset <= 2 && offset < widget.dramas.length;
              offset++
            )
              widget.dramas[(_currentIndex + offset) % widget.dramas.length],
          ];
    return SizedBox(
      height: widget.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (drama == null)
            const _HeroCoverFallback()
          else
            PageView.builder(
              key: const ValueKey('home-featured-carousel'),
              controller: _pageController,
              itemCount: widget.dramas.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                final pageDrama = widget.dramas[index];
                return Semantics(
                  button: true,
                  image: true,
                  label: '打开${pageDrama.title}详情',
                  child: InkWell(
                    key: ValueKey('home-featured-poster-$index'),
                    onTap: () => widget.onOpen(pageDrama),
                    child: _HeroCover(
                      imageUrl: widget.api.coverUrl(pageDrama)?.toString(),
                    ),
                  ),
                );
              },
            ),
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xE6000000),
                    Color(0xD9000000),
                    Colors.transparent,
                    Color(0xDD000000),
                    Color(0xEB000000),
                  ],
                  stops: [0, .18, .4, .66, 1],
                ),
              ),
            ),
          ),
          Positioned(
            top: widget.topInset,
            left: 20,
            right: 12,
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.movie_filter_rounded,
                            key: ValueKey('brand-title-icon'),
                            color: Colors.white,
                            size: 24,
                          ),
                          SizedBox(width: 8),
                          Text(
                            '剧有戏',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            key: ValueKey('brand-description-icon'),
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 6),
                          Text(
                            '好戏正在上演',
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: widget.onSearch,
                  tooltip: '搜索剧集',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.black.withValues(alpha: .32),
                  ),
                  icon: const Icon(Icons.search),
                ),
              ],
            ),
          ),
          if (drama != null)
            Positioned(
              left: 20,
              right: 76,
              bottom: 144,
              child: IgnorePointer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      drama.title,
                      key: const ValueKey('home-featured-title'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        shadows: [
                          Shadow(color: Colors.black54, blurRadius: 12),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      episodeLabel.isNotEmpty
                          ? '${drama.category.isEmpty ? '短剧' : drama.category} · $episodeLabel'
                          : (drama.category.isEmpty ? '短剧' : drama.category),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFF0F0F0),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        shadows: [Shadow(color: Colors.black87, blurRadius: 8)],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (miniDramas.isNotEmpty)
            Positioned(
              left: 20,
              bottom: 36,
              child: Row(
                children: [
                  for (final miniDrama in miniDramas)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _MiniDramaPoster(
                        drama: miniDrama,
                        imageUrl: widget.api.coverUrl(miniDrama)?.toString(),
                        onTap: () => widget.onOpen(miniDrama),
                      ),
                    ),
                ],
              ),
            ),
          if (drama != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 32,
              child: Semantics(
                label: '第${_currentIndex + 1}部，共${widget.dramas.length}部推荐短剧',
                child: ExcludeSemantics(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var dot = 0; dot < widget.dramas.length; dot++)
                        Container(
                          width: dot == _currentIndex ? 8 : 6,
                          height: dot == _currentIndex ? 8 : 6,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: dot == _currentIndex
                                ? Colors.white
                                : Colors.white.withValues(alpha: .48),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroCover extends StatelessWidget {
  const _HeroCover({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null) return const _HeroCoverFallback();
    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const _HeroCoverFallback(),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : const _HeroCoverFallback(loading: true),
    );
  }
}

class _HeroCoverFallback extends StatelessWidget {
  const _HeroCoverFallback({this.loading = false});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF424650), Color(0xFF17181C)],
        ),
      ),
      child: Center(
        child: loading
            ? const CircularProgressIndicator(color: Colors.white70)
            : const Icon(
                Icons.theaters_outlined,
                color: Colors.white70,
                size: 42,
              ),
      ),
    );
  }
}

class _MiniDramaPoster extends StatelessWidget {
  const _MiniDramaPoster({
    required this.drama,
    required this.imageUrl,
    required this.onTap,
  });

  final Drama drama;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: drama.title,
      child: Semantics(
        button: true,
        image: true,
        label: '打开${drama.title}详情',
        child: Material(
          color: const Color(0xFF30343C),
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('home-featured-mini-poster-${drama.id}'),
            onTap: onTap,
            child: SizedBox(
              width: 60,
              height: 82,
              child: imageUrl == null
                  ? const _HeroCoverFallback()
                  : Image.network(
                      imageUrl!,
                      cacheWidth: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _HeroCoverFallback(),
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                          ? child
                          : const _HeroCoverFallback(loading: true),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({
    super.key,
    required this.api,
    required this.onSearch,
    this.previewMode = false,
  });

  final LibraryApi api;
  final VoidCallback onSearch;
  final bool previewMode;

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _controller = TextEditingController();
  List<Drama> _results = const [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final keyword = _controller.text.trim();
    if (keyword.isEmpty || widget.previewMode) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await widget.api.search(keyword);
      if (mounted) setState(() => _results = results);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
            sliver: SliverToBoxAdapter(
              child: Text(
                '找一部好戏',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _search(),
                decoration: InputDecoration(
                  hintText: '搜索剧名、类型或关键词',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    onPressed: _search,
                    tooltip: '开始搜索',
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ),
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _ErrorState(message: _error!, onRetry: _search),
            )
          else if (_results.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(message: '输入关键词，开始找戏'),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.crossAxisExtent >= 900
                      ? 5
                      : constraints.crossAxisExtent >= 600
                      ? 4
                      : 3;
                  return SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => DramaCard(
                        drama: _results[index],
                        api: widget.api,
                        showReleaseStatus: false,
                        onTap: () => _openPlayback(_results[index]),
                      ),
                      childCount: _results.length,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 18,
                      childAspectRatio: columns == 3 ? .59 : .62,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _openPlayback(Drama drama) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ShortDramaDetailsPage(
          api: widget.api,
          drama: drama,
          episodes: drama.episodes,
          initialEpisodeNumber: drama.firstEpisode?.number ?? 1,
          onSearch: widget.onSearch,
          previewMode: widget.previewMode,
        ),
      ),
    );
  }
}

class FollowingPage extends StatefulWidget {
  const FollowingPage({
    super.key,
    required this.api,
    required this.onSearch,
    this.previewMode = false,
    this.openCollection = false,
    this.active = true,
  });

  final LibraryApi api;
  final VoidCallback onSearch;
  final bool previewMode;
  final bool openCollection;
  final bool active;

  @override
  State<FollowingPage> createState() => _FollowingPageState();
}

class _FollowingPageState extends State<FollowingPage> {
  static const _hotPageSize = 15;
  static const _hotMaximum = 150;

  List<FollowingEntry> _entries = const [];
  List<Drama> _dramas = const [];
  List<Drama> _mostViewed = const [];
  List<Drama> _hotDramas = const [];
  Map<String, PlaybackHistoryEntry> _historyById = const {};
  String _filter = '追剧中';
  bool _showCollection = false;
  bool _loading = false;
  String? _error;
  int _loadedHotCount = _hotPageSize;
  late final ScrollController _discoveryScrollController = ScrollController()
    ..addListener(_loadMoreHotDramas);

  void _loadMoreHotDramas() {
    if (!_discoveryScrollController.hasClients ||
        _loadedHotCount >= _hotDramas.length ||
        _loadedHotCount >= _hotMaximum ||
        _discoveryScrollController.position.extentAfter > 240) {
      return;
    }
    setState(() {
      _loadedHotCount = min(
        _loadedHotCount + _hotPageSize,
        min(_hotDramas.length, _hotMaximum),
      );
    });
  }

  @override
  void dispose() {
    _discoveryScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FollowingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openCollection != oldWidget.openCollection) {
      _showCollection = widget.openCollection;
    }
    if (!oldWidget.active && widget.active && !widget.previewMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.active) _load();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.previewMode) {
      _entries = const [
        FollowingEntry(
          dramaId: 'preview-following',
          title: '追剧样例',
          category: '短剧',
          saved: true,
          knownEpisodes: 2,
        ),
      ];
      _dramas = const [
        Drama(
          id: 'preview-following',
          title: '追剧样例',
          category: '短剧',
          episodeCount: 3,
          episodes: [
            Episode(number: 1, title: '第1集'),
            Episode(number: 2, title: '第2集'),
            Episode(number: 3, title: '第3集'),
          ],
        ),
      ];
      _hotDramas = buildHotDramas(_dramas);
      _historyById = const {
        'preview-following': PlaybackHistoryEntry(
          dramaId: 'preview-following',
          title: '追剧样例',
          episodeNumber: 2,
        ),
      };
    } else if (widget.active) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await widget.api.fetchFollowing();
      final dramas = await widget.api.fetchDramas();
      final history = await widget.api.fetchPlaybackHistory();
      if (mounted) {
        setState(() {
          _entries = entries.where((entry) => entry.saved).toList();
          _dramas = dramas;
          _historyById = {for (final item in history) item.dramaId: item};
          _mostViewed = buildMostViewedDramas(dramas);
          _hotDramas = buildHotDramas(dramas);
          _loadedHotCount = min(_hotPageSize, _hotDramas.length);
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _remove(FollowingEntry entry) async {
    if (widget.previewMode) {
      setState(
        () => _entries = _entries
            .where((item) => item.dramaId != entry.dramaId)
            .toList(),
      );
      return;
    }
    try {
      await widget.api.setFollowing(entry.dramaId, saved: false);
      if (mounted) _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  List<FollowingEntry> get _visibleEntries {
    return _entries.where((entry) {
      switch (_filter) {
        case '已看完':
          return entry.completed;
        case '全部':
          return true;
        default:
          return !entry.completed;
      }
    }).toList();
  }

  Drama? _dramaFor(FollowingEntry entry) {
    for (final drama in _dramas) {
      if (drama.id == entry.dramaId) return drama;
    }
    return null;
  }

  void _openEntry(FollowingEntry entry) {
    final drama = _dramaFor(entry);
    if (drama == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('剧集信息暂不可用')));
      return;
    }
    _openDrama(
      drama,
      _historyById[entry.dramaId]?.episodeNumber ??
          drama.firstEpisode?.number ??
          1,
    );
  }

  void _openDrama(Drama drama, int initialEpisodeNumber) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ShortDramaDetailsPage(
          api: widget.api,
          drama: drama,
          episodes: drama.episodes,
          initialEpisodeNumber: initialEpisodeNumber,
          onSearch: widget.onSearch,
          previewMode: widget.previewMode,
        ),
      ),
    );
  }

  Widget _wideArtwork(Drama drama) {
    final url = widget.api.coverUrl(drama)?.toString();
    if (url == null) {
      return const ColoredBox(
        color: _followingSurface,
        child: Center(
          child: Icon(Icons.theaters_rounded, color: _followingSecondary),
        ),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: _followingSurface,
        child: Center(
          child: Icon(Icons.theaters_rounded, color: _followingSecondary),
        ),
      ),
    );
  }

  Widget _sectionHeading(String title, {VoidCallback? onMore}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 23, 16, 10),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          if (onMore != null)
            TextButton.icon(
              onPressed: onMore,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.chevron_right_rounded, size: 18),
              label: const Text('查看全部'),
              style: TextButton.styleFrom(
                foregroundColor: _followingSecondary,
                minimumSize: const Size(44, 40),
                padding: const EdgeInsets.symmetric(horizontal: 2),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDiscovery(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final heroWidth = (width - 48).clamp(240.0, 600.0).toDouble();
    final heroHeight = heroWidth * .51;
    final railWidth = (width * .44).clamp(155.0, 220.0).toDouble();
    final hotWidth = (width - 40) / 2;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      key: const ValueKey('following-system-ui'),
      value: const SystemUiOverlayStyle(
        statusBarColor: _followingBackground,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: ColoredBox(
        color: _followingBackground,
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: widget.previewMode ? () async {} : _load,
            child: CustomScrollView(
              key: const ValueKey('following-discovery-scroll'),
              controller: _discoveryScrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (_loading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _ErrorState(message: _error!, onRetry: _load),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: heroHeight + 12,
                      child: _mostViewed.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: _followingSurface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: Text(
                                    '暂无播放量数据',
                                    style: TextStyle(
                                      color: _followingSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              key: const ValueKey('following-hero-rail'),
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              itemCount: _mostViewed.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final drama = _mostViewed[index];
                                return SizedBox(
                                  width: heroWidth,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                      key: ValueKey(
                                        'following-hero-drama-${drama.id}',
                                      ),
                                      onTap: () => _openDrama(
                                        drama,
                                        drama.firstEpisode?.number ?? 1,
                                      ),
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          _wideArtwork(drama),
                                          const DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.transparent,
                                                  Color(0xDD000000),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 12,
                                            left: 12,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color: _followingAccent,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 7,
                                                  vertical: 4,
                                                ),
                                                child: Text(
                                                  '高播放',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            left: 14,
                                            right: 14,
                                            bottom: 14,
                                            child: Text(
                                              drama.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 21,
                                                fontWeight: FontWeight.w800,
                                                shadows: [
                                                  Shadow(
                                                    blurRadius: 8,
                                                    color: Colors.black,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _sectionHeading(
                      '猜你在追',
                      onMore: () => setState(() => _showCollection = true),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _mostViewed.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              '暂无播放量数据',
                              style: TextStyle(color: _followingSecondary),
                            ),
                          )
                        : SizedBox(
                            height: railWidth * 9 / 16 + 48,
                            child: ListView.separated(
                              key: const ValueKey('following-most-viewed-rail'),
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: _mostViewed.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 9),
                              itemBuilder: (context, index) {
                                final drama = _mostViewed[index];
                                return SizedBox(
                                  width: railWidth,
                                  child: InkWell(
                                    key: ValueKey(
                                      'following-most-viewed-${drama.id}',
                                    ),
                                    onTap: () => _openDrama(
                                      drama,
                                      drama.firstEpisode?.number ?? 1,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          height: railWidth * 9 / 16,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: SizedBox.expand(
                                              child: _wideArtwork(drama),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          drama.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          formatPlayCount(drama.views),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: _followingSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                  SliverToBoxAdapter(child: _sectionHeading('正在热播')),
                  if (_hotDramas.isEmpty)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '暂无推荐短剧',
                          style: TextStyle(color: _followingSecondary),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      sliver: SliverGrid.builder(
                        key: const ValueKey('following-hot-grid'),
                        itemCount: min(_loadedHotCount, _hotDramas.length),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 14,
                          mainAxisExtent: hotWidth * 9 / 16 + 48,
                        ),
                        itemBuilder: (context, index) {
                          final drama = _hotDramas[index];
                          return InkWell(
                            key: ValueKey('following-hot-drama-${drama.id}'),
                            onTap: () => _openDrama(
                              drama,
                              drama.firstEpisode?.number ?? 1,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AspectRatio(
                                  aspectRatio: 16 / 9,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox.expand(
                                      child: _wideArtwork(drama),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  drama.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  drama.category.isEmpty
                                      ? drama.episodeLabel
                                      : drama.category,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _followingSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Center(
                        child: Text(
                          _loadedHotCount < _hotDramas.length &&
                                  _loadedHotCount < _hotMaximum
                              ? '上拉加载更多'
                              : '已展示全部热播短剧',
                          style: const TextStyle(
                            color: _followingSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_showCollection) return _buildDiscovery(context);
    return Theme(
      data: _theme(Brightness.dark),
      child: Builder(builder: _buildCollection),
    );
  }

  Widget _buildCollection(BuildContext context) {
    final visibleEntries = _visibleEntries;
    final ongoingCount = _entries.where((entry) => !entry.completed).length;
    final completedCount = _entries.where((entry) => entry.completed).length;
    final filterCounts = {
      '追剧中': ongoingCount,
      '已看完': completedCount,
      '全部': _entries.length,
    };
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.surfaceContainerHighest,
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: widget.previewMode ? () async {} : _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(28, 22, 24, 8),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () =>
                            setState(() => _showCollection = false),
                        tooltip: '返回追剧',
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '追剧',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: colors.onSurface,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 30,
                                    letterSpacing: -0.7,
                                  ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              '收藏喜欢的故事，随时接着看',
                              key: const ValueKey('following-count-summary'),
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    color: colors.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('following-search-button'),
                        onPressed: widget.onSearch,
                        tooltip: '搜索短剧',
                        color: colors.onSurface,
                        iconSize: 27,
                        icon: const Icon(Icons.search_rounded),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    key: const ValueKey('following-filter-control'),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      border: Border.all(
                        color: colors.outline.withValues(alpha: .8),
                        width: 1.2,
                      ),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Row(
                        children: [
                          for (final filter in const ['追剧中', '已看完', '全部'])
                            Expanded(
                              child: _FollowingFilterChip(
                                label: filter,
                                count: filterCounts[filter] ?? 0,
                                countKey: switch (filter) {
                                  '追剧中' => const ValueKey(
                                    'following-filter-ongoing-count',
                                  ),
                                  '已看完' => const ValueKey(
                                    'following-filter-completed-count',
                                  ),
                                  _ => const ValueKey(
                                    'following-filter-all-count',
                                  ),
                                },
                                selected: _filter == filter,
                                onTap: () => setState(() => _filter = filter),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _ErrorState(message: _error!, onRetry: _load),
                )
              else if (visibleEntries.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(message: '还没有追剧，去首页挑一部好戏吧'),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                  sliver: SliverList.separated(
                    itemCount: visibleEntries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 9),
                    itemBuilder: (context, index) {
                      final entry = visibleEntries[index];
                      final drama = _dramaFor(entry);
                      final totalEpisodes = drama?.episodeCount;
                      final currentEpisode =
                          _historyById[entry.dramaId]?.episodeNumber ?? 0;
                      final hasProgress =
                          currentEpisode > 0 &&
                          totalEpisodes != null &&
                          totalEpisodes > 0;
                      final progress = hasProgress
                          ? (currentEpisode / totalEpisodes).clamp(0.0, 1.0)
                          : 0.0;
                      return Material(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(17),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(17),
                          onTap: () => _openEntry(entry),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(17),
                              border: Border.all(
                                color: colors.outline.withValues(alpha: .25),
                              ),
                            ),
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              children: [
                                _FollowingPoster(
                                  imageUrl: drama == null
                                      ? null
                                      : widget.api.coverUrl(drama),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: SizedBox(
                                    height: 116,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                entry.title.isEmpty
                                                    ? '未命名剧集'
                                                    : entry.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: colors.onSurface,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            _FollowingStatus(
                                              completed: entry.completed,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          entry.category.trim().isEmpty
                                              ? '短剧'
                                              : entry.category.trim(),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: colors.onSurfaceVariant,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                currentEpisode > 0
                                                    ? '看到第$currentEpisode集'
                                                    : '尚未观看',
                                                style: TextStyle(
                                                  color:
                                                      colors.onSurfaceVariant,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            if (hasProgress)
                                              Text(
                                                '共$totalEpisodes集',
                                                key: const ValueKey(
                                                  'following-progress-total',
                                                ),
                                                style: TextStyle(
                                                  color:
                                                      colors.onSurfaceVariant,
                                                  fontSize: 11,
                                                ),
                                              ),
                                          ],
                                        ),
                                        if (hasProgress) ...[
                                          const SizedBox(height: 5),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                            child: LinearProgressIndicator(
                                              key: ValueKey(
                                                'following-progress-${entry.dramaId}',
                                              ),
                                              value: progress,
                                              minHeight: 3,
                                              backgroundColor: colors.outline
                                                  .withValues(alpha: .22),
                                              color: _vermilion,
                                            ),
                                          ),
                                        ],
                                        const Spacer(),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: SizedBox(
                                                height: 36,
                                                child: FilledButton.icon(
                                                  onPressed: () =>
                                                      _openEntry(entry),
                                                  icon: const Icon(
                                                    Icons.play_arrow_rounded,
                                                    size: 17,
                                                  ),
                                                  label: Text(
                                                    entry.completed
                                                        ? '再次观看'
                                                        : '继续观看',
                                                    maxLines: 1,
                                                  ),
                                                  style: FilledButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                        ),
                                                    textStyle: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () => _remove(entry),
                                              tooltip: '取消追剧',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              constraints:
                                                  const BoxConstraints.tightFor(
                                                    width: 36,
                                                    height: 36,
                                                  ),
                                              padding: EdgeInsets.zero,
                                              icon: Icon(
                                                Icons.bookmark_remove_outlined,
                                                color: colors.onSurfaceVariant,
                                                size: 19,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
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

class _FollowingFilterChip extends StatelessWidget {
  const _FollowingFilterChip({
    required this.label,
    required this.count,
    required this.countKey,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Key countKey;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label，$count部${selected ? '，已选中' : ''}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF493536) : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : colors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '$count',
                key: countKey,
                style: TextStyle(
                  color: selected ? Colors.white : colors.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FollowingStatus extends StatelessWidget {
  const _FollowingStatus({required this.completed});

  final bool completed;

  @override
  Widget build(BuildContext context) {
    final color = completed ? _muted : _vermilion;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        completed ? '已看完' : '追剧中',
        style: TextStyle(
          color: color,
          fontSize: 10,
          height: 1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FollowingPoster extends StatelessWidget {
  const _FollowingPoster({required this.imageUrl});

  final Uri? imageUrl;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 116,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: imageUrl == null
            ? const _FollowingPosterFallback()
            : Image.network(
                imageUrl.toString(),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _FollowingPosterFallback(),
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : const _FollowingPosterFallback(),
              ),
      ),
    );
  }
}

class _FollowingPosterFallback extends StatelessWidget {
  const _FollowingPosterFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF313844), Color(0xFF17181C)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.theaters_outlined, color: Colors.white70, size: 30),
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.api,
    required this.onOpenFollowing,
    required this.onSearch,
    this.active = true,
    this.previewMode = false,
  });

  final LibraryApi api;
  final VoidCallback onOpenFollowing;
  final VoidCallback onSearch;
  final bool active;
  final bool previewMode;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with RouteAware {
  ViewerInfo? _viewer;
  List<FollowingEntry> _historyEntries = const [];
  List<Drama> _dramas = const [];
  String? _error;
  PageRoute<dynamic>? _subscribedRoute;

  @override
  void initState() {
    super.initState();
    if (widget.previewMode) {
      _historyEntries = const [
        FollowingEntry(
          dramaId: 'preview-profile-history',
          title: '历史样例',
          category: '短剧',
          saved: true,
          knownEpisodes: 2,
        ),
      ];
      _dramas = const [
        Drama(
          id: 'preview-profile-history',
          title: '历史样例',
          category: '短剧',
          episodeCount: 3,
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
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active && !widget.previewMode) _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _subscribedRoute) return;
    _pageRouteObserver.unsubscribe(this);
    _subscribedRoute = route is PageRoute<dynamic> ? route : null;
    if (_subscribedRoute case final route?) {
      _pageRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    if (widget.active && !widget.previewMode) _load();
  }

  @override
  void dispose() {
    _pageRouteObserver.unsubscribe(this);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final viewer = await widget.api.fetchViewer();
      final history = await widget.api.fetchPlaybackHistory();
      final dramas = await widget.api.fetchDramas();
      if (mounted) {
        setState(() {
          _viewer = viewer;
          _historyEntries = history
              .take(12)
              .map(
                (entry) => FollowingEntry(
                  dramaId: entry.dramaId,
                  title: entry.title,
                  category: entry.category,
                  knownEpisodes: entry.episodeNumber,
                ),
              )
              .toList();
          _dramas = dramas;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Drama? _dramaFor(FollowingEntry entry) {
    for (final drama in _dramas) {
      if (drama.id == entry.dramaId) return drama;
    }
    return null;
  }

  void _showUnavailable(String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label功能暂未开放')));
  }

  void _openHistory(FollowingEntry entry) {
    final drama = _dramaFor(entry);
    if (drama == null) {
      _showUnavailable('剧集信息');
      return;
    }
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ShortDramaDetailsPage(
          api: widget.api,
          drama: drama,
          episodes: drama.episodes,
          initialEpisodeNumber: entry.knownEpisodes > 0
              ? entry.knownEpisodes
              : drama.firstEpisode?.number ?? 1,
          onSearch: widget.onSearch,
          previewMode: widget.previewMode,
        ),
      ),
    );
  }

  void _showSettings() {
    final viewer = _viewer;
    final source = viewer?.sources.isNotEmpty == true
        ? viewer!.sources.join('、')
        : '红果剧库';
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              leading: Icon(Icons.dark_mode_outlined),
              title: Text('深色模式'),
              subtitle: Text('跟随系统外观设置'),
            ),
            ListTile(
              leading: const Icon(Icons.source_outlined),
              title: const Text('数据来源'),
              subtitle: Text(source),
            ),
            const ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('游客模式'),
              subtitle: Text('追剧数据保存在当前设备'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewer = _viewer;
    final account = viewer?.account?.trim();
    final displayName = account == null || account.isEmpty ? '游客观众' : account;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      key: const ValueKey('profile-system-ui'),
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.paddingOf(context).top,
            child: const DecoratedBox(
              key: ValueKey('profile-status-bar-background'),
              decoration: BoxDecoration(gradient: _profileHeaderGradient),
            ),
          ),
          SafeArea(
            child: ListView(
              key: const ValueKey('profile-scroll'),
              padding: const EdgeInsets.only(bottom: 28),
              children: [
                _ProfileHero(
                  displayName: displayName,
                  onVip: () => _showUnavailable('会员中心'),
                  onTheme: () => _showUnavailable('深色模式'),
                  onSettings: _showSettings,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _ProfileQuickActions(onAction: _showUnavailable),
                      const SizedBox(height: 1),
                      _ProfileHistorySection(
                        entries: _historyEntries,
                        dramaFor: _dramaFor,
                        api: widget.api,
                        onMore: widget.onOpenFollowing,
                        onOpen: _openHistory,
                      ),
                      const SizedBox(height: 8),
                      if (_error != null)
                        _ErrorState(message: _error!, onRetry: _load)
                      else
                        _ProfileMenu(
                          onAction: _showUnavailable,
                          onAbout: () => _showUnavailable('关于剧有戏'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.displayName,
    required this.onVip,
    required this.onTheme,
    required this.onSettings,
  });

  final String displayName;
  final VoidCallback onVip;
  final VoidCallback onTheme;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('profile-hero'),
      decoration: const BoxDecoration(
        gradient: _profileHeaderGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 12, 16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: onTheme,
                  tooltip: '深色模式',
                  icon: const Icon(Icons.nightlight_outlined),
                  color: Colors.white,
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                  padding: EdgeInsets.zero,
                ),
                IconButton(
                  onPressed: onSettings,
                  tooltip: '设置',
                  icon: const Icon(Icons.settings_outlined),
                  color: Colors.white,
                  constraints: const BoxConstraints.tightFor(
                    width: 44,
                    height: 44,
                  ),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            Row(
              children: [
                const CircleAvatar(
                  radius: 34,
                  backgroundColor: Colors.white,
                  child: CircleAvatar(
                    radius: 31,
                    backgroundColor: _ticketGold,
                    child: Icon(Icons.person, color: _ink, size: 42),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'UID：当前设备访客',
                        style: TextStyle(
                          color: Color(0xFFD5D7DB),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: onVip,
                  icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                  label: const Text('成为VIP'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _profileVip,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(96, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileQuickActions extends StatelessWidget {
  const _ProfileQuickActions({required this.onAction});

  final ValueChanged<String> onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('profile-quick-actions'),
      margin: EdgeInsets.zero,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Expanded(
              child: _ProfileQuickAction(
                icon: Icons.chat_bubble_rounded,
                color: const Color(0xFFFFB33E),
                label: '我的消息',
                onTap: onAction,
              ),
            ),
            Expanded(
              child: _ProfileQuickAction(
                icon: Icons.favorite_rounded,
                color: const Color(0xFFFF6A45),
                label: '我的点赞',
                onTap: onAction,
              ),
            ),
            Expanded(
              child: _ProfileQuickAction(
                icon: Icons.forum_rounded,
                color: const Color(0xFF20D6A0),
                label: '我的评论',
                onTap: onAction,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileQuickAction extends StatelessWidget {
  const _ProfileQuickAction({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label，功能暂未开放',
      child: InkWell(
        onTap: () => onTap(label.replaceFirst('我的', '')),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileHistorySection extends StatelessWidget {
  const _ProfileHistorySection({
    required this.entries,
    required this.dramaFor,
    required this.api,
    required this.onMore,
    required this.onOpen,
  });

  final List<FollowingEntry> entries;
  final Drama? Function(FollowingEntry entry) dramaFor;
  final LibraryApi api;
  final VoidCallback onMore;
  final ValueChanged<FollowingEntry> onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('profile-history-card'),
      margin: EdgeInsets.zero,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 0, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  const Text(
                    '最近看过',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    key: const ValueKey('profile-history-more'),
                    onPressed: onMore,
                    icon: const Text('更多'),
                    label: const Icon(Icons.chevron_right),
                    style: TextButton.styleFrom(
                      foregroundColor: _muted,
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            if (entries.isEmpty)
              const SizedBox(height: 72, child: Center(child: Text('暂无播放历史')))
            else
              SizedBox(
                height: 154,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 12),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    final drama = dramaFor(entry);
                    return _ProfileHistoryCard(
                      entry: entry,
                      imageUrl: drama == null ? null : api.coverUrl(drama),
                      onTap: () => onOpen(entry),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHistoryCard extends StatelessWidget {
  const _ProfileHistoryCard({
    required this.entry,
    required this.imageUrl,
    required this.onTap,
  });

  final FollowingEntry entry;
  final Uri? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '打开${entry.title}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 104,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 104,
                height: 112,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageUrl == null
                      ? const _FollowingPosterFallback()
                      : Image.network(
                          imageUrl.toString(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const _FollowingPosterFallback(),
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                              ? child
                              : const _FollowingPosterFallback(),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                entry.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (entry.knownEpisodes > 0)
                Text(
                  '看到第${entry.knownEpisodes}集',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({required this.onAction, required this.onAbout});

  final ValueChanged<String> onAction;
  final VoidCallback onAbout;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.tune_rounded, '看剧偏好'),
      (Icons.person_add_alt_1_outlined, '邀请好友'),
      (Icons.videocam_outlined, '上传视频'),
      (Icons.workspace_premium_outlined, '会员中心'),
    ];
    return Card(
      key: const ValueKey('profile-menu-card'),
      margin: EdgeInsets.zero,
      elevation: 0,
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            ListTile(
              minTileHeight: 48,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              leading: Icon(items[index].$1, size: 22),
              title: Text(items[index].$2),
              trailing: const Icon(Icons.chevron_right, color: _muted),
              visualDensity: VisualDensity.compact,
              onTap: () => onAction(items[index].$2),
            ),
            Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: Colors.black.withValues(alpha: 0.15),
            ),
          ],
          ListTile(
            minTileHeight: 48,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            leading: const Icon(Icons.info_outline, size: 22),
            title: const Text('关于剧有戏'),
            trailing: const Icon(Icons.chevron_right, color: _muted),
            visualDensity: VisualDensity.compact,
            onTap: onAbout,
          ),
        ],
      ),
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<CategoryFilter> categories;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final itemHeight = 48.0 + (textScale > 1 ? (textScale - 1) * 12 : 0);
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: itemHeight + 8,
      child: ListView.separated(
        key: const ValueKey('home-category-rail'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final active = selected == category.label;
          final foreground = active ? colors.primary : colors.onSurfaceVariant;
          return Semantics(
            button: true,
            selected: active,
            label:
                '${category.label}，${category.count}部${active ? '，已选中' : ''}',
            child: InkWell(
              onTap: () => onSelected(category.label),
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: itemHeight,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _categoryIcon(category.label),
                          size: 18,
                          color: foreground,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          category.label,
                          style: TextStyle(
                            color: active ? colors.primary : colors.onSurface,
                            fontSize: 14,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${category.count}',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: active ? 16 : 0,
                      height: 2,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

IconData _categoryIcon(String category) {
  switch (category) {
    case '追剧历史':
      return Icons.history;
    case '精选榜':
      return Icons.bar_chart_rounded;
    case '推荐':
      return Icons.thumb_up_alt_rounded;
    case '剧场':
      return Icons.movie_filter_rounded;
    case '逆袭':
      return Icons.trending_up_rounded;
    default:
      return Icons.category_outlined;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.theaters_outlined, size: 42, color: _muted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted),
          ),
        ],
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_outlined, size: 42, color: _vermilion),
          const SizedBox(height: 12),
          Text(
            '剧库暂时没有响应',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('重试'),
          ),
        ],
      ),
    ),
  );
}
