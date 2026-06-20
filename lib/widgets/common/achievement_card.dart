import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../services/share_service.dart';
import '../../extensions/widget_to_image.dart';

class AchievementCard extends StatefulWidget {
  final String achievementKey;
  final Map<String, dynamic> achievement;
  final bool isEarned;
  final bool isNewlyUnlocked;

  const AchievementCard({
    super.key,
    required this.achievementKey,
    required this.achievement,
    required this.isEarned,
    required this.isNewlyUnlocked,
  });

  @override
  State<AchievementCard> createState() => _AchievementCardState();
}

class _AchievementCardState extends State<AchievementCard> {
  final GlobalKey _globalKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareAchievement() async {
    if (!widget.isEarned || _isSharing) return;
    setState(() => _isSharing = true);
    try {
      final file = await ShareService.captureWidget(
        _globalKey,
        'achievement_${widget.achievementKey}',
      );

      if (mounted && file != null) {
        final String shareText =
            "I just unlocked the '${widget.achievement['title']}' badge in Orbit! 🚀 Can you beat my streak?";
        ShareService.showShareBottomSheet(
          context: context,
          imageFile: file,
          shareText: shareText,
        );
      }
    } catch (e) {
      debugPrint('Error sharing achievement: $e');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget card = GestureDetector(
      onTap: widget.isEarned ? _shareAchievement : null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              color: widget.isEarned
                  ? Color.alphaBlend(
                      widget.achievement['color'].withOpacity(0.1),
                      Colors.white,
                    )
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.isEarned
                    ? widget.achievement['color'].withOpacity(0.5)
                    : Colors.transparent,
                width: 2,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Builder(
                  builder: (context) {
                    Widget iconWidget = Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: widget.isEarned
                            ? widget.achievement['color']
                            : Colors.grey[300],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.achievement['icon'],
                        color: Colors.white,
                        size: 32,
                      ),
                    );
                    Animate animatedIcon = iconWidget
                        .animate(target: widget.isEarned ? 1 : 0)
                        .scaleXY(
                          end: 1.15,
                          duration: 600.ms,
                          curve: Curves.easeOutBack,
                        );

                    if (widget.achievementKey == '100_Day_Streak' &&
                        widget.isEarned) {
                      return animatedIcon
                          .animate(onPlay: (c) => c.repeat())
                          .shimmer(duration: 2000.ms, color: Colors.white70);
                    }
                    return animatedIcon.shimmer(
                      delay: 400.ms,
                      duration: 1500.ms,
                      color: Colors.white54,
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  widget.achievement['title'],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color:
                        widget.isEarned ? const Color(0xFF1A1F36) : Colors.grey,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.achievement['description'],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:
                        widget.isEarned ? Colors.grey[700] : Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                if (widget.isEarned) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.ios_share_rounded,
                        size: 14,
                        color: widget.achievement['color'],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Share',
                        style: TextStyle(
                          color: widget.achievement['color'],
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (_isSharing)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ).toRepaintBoundary(_globalKey),
    );

    Animate animatedCard = card
        .animate(target: widget.isEarned ? 1 : 0)
        .fade(duration: 400.ms)
        .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);

    if (widget.isNewlyUnlocked) {
      animatedCard = animatedCard
          .flipH(
            begin: -1,
            end: 0,
            duration: 800.ms,
            curve: Curves.easeOutBack,
            delay: 200.ms,
          )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .boxShadow(
            begin: const BoxShadow(
              color: Colors.transparent,
              blurRadius: 0,
              spreadRadius: 0,
            ),
            end: BoxShadow(
              color: widget.achievement['color'].withOpacity(0.7),
              blurRadius: 24,
              spreadRadius: 8,
            ),
            duration: 1200.ms,
            curve: Curves.easeInOut,
          );
    }

    return animatedCard;
  }
}
