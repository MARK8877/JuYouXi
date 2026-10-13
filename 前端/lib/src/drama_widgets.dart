import 'package:flutter/material.dart';

import 'library_api.dart';
import 'models.dart';

const _cardInk = Color(0xFF17181C);
const _cardMuted = Color(0xFF686C73);
const _cardRed = Color(0xFFC93B32);

class DramaCard extends StatelessWidget {
  const DramaCard({
    super.key,
    required this.drama,
    required this.api,
    required this.onTap,
    this.showReleaseStatus = true,
    this.showEpisodeCountOnCover = false,
  });

  final Drama drama;
  final LibraryApi api;
  final VoidCallback onTap;
  final bool showReleaseStatus;
  final bool showEpisodeCountOnCover;

  @override
  Widget build(BuildContext context) {
    final imageUrl = api.coverUrl(drama);
    final episodeCount = drama.episodeCount;
    final episodeLabel = showReleaseStatus
        ? drama.episodeLabel
        : episodeCount == null
        ? ''
        : '$episodeCount集';
    final showEpisodeCount =
        showEpisodeCountOnCover && episodeCount != null && episodeCount > 0;
    return Semantics(
      button: true,
      label: showEpisodeCount
          ? '打开 ${drama.title}，共$episodeCount集'
          : '打开 ${drama.title}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null)
                      Image.network(
                        imageUrl.toString(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const _CoverFallback(),
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                            ? child
                            : const _CoverFallback(loading: true),
                      )
                    else
                      const _CoverFallback(),
                    if (showEpisodeCount)
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: DecoratedBox(
                          key: ValueKey(
                            'drama-episode-count-badge-${drama.id}',
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .68),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            child: Text(
                              '$episodeCount集',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (showReleaseStatus && drama.releaseStatus.isNotEmpty)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: DecoratedBox(
                          key: const ValueKey('drama-release-status-badge'),
                          decoration: BoxDecoration(
                            color: _cardRed,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            child: Text(
                              drama.releaseStatus,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              drama.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            if (showEpisodeCountOnCover) ...[
              const SizedBox(height: 3),
              Text(
                drama.category.isEmpty ? '短剧' : drama.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: _cardMuted),
              ),
            ] else ...[
              const SizedBox(height: 3),
              Text(
                episodeLabel.isEmpty
                    ? (drama.category.isEmpty ? '短剧' : drama.category)
                    : episodeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: _cardMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DramaDetailsSheet extends StatefulWidget {
  const DramaDetailsSheet({super.key, required this.api, required this.drama});

  final LibraryApi api;
  final Drama drama;

  @override
  State<DramaDetailsSheet> createState() => _DramaDetailsSheetState();
}

class _DramaDetailsSheetState extends State<DramaDetailsSheet> {
  bool _saving = false;
  bool _saved = false;

  Future<void> _toggleSaved() async {
    setState(() => _saving = true);
    try {
      await widget.api.setFollowing(widget.drama.id, saved: !_saved);
      if (mounted) setState(() => _saved = !_saved);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final drama = widget.drama;
    final imageUrl = widget.api.coverUrl(drama);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 96,
                  height: 128,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: imageUrl == null
                        ? const _CoverFallback()
                        : Image.network(
                            imageUrl.toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const _CoverFallback(),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        drama.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        drama.category.isEmpty ? '短剧' : drama.category,
                        style: const TextStyle(color: _cardMuted),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        drama.episodeLabel.isEmpty
                            ? '剧集信息待补充'
                            : drama.episodeLabel,
                        style: const TextStyle(color: _cardMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              drama.description.isEmpty
                  ? '暂无简介，先把这部戏放进追剧清单。'
                  : drama.description,
              style: const TextStyle(height: 1.55),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _saving ? null : _toggleSaved,
                icon: Icon(
                  _saved ? Icons.bookmark : Icons.bookmark_add_outlined,
                ),
                label: Text(_saved ? '已加入追剧' : '加入追剧'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverFallback extends StatelessWidget {
  const _CoverFallback({this.loading = false});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _cardInk,
      alignment: Alignment.center,
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white54,
              ),
            )
          : const Icon(
              Icons.theaters_outlined,
              color: Colors.white54,
              size: 32,
            ),
    );
  }
}
