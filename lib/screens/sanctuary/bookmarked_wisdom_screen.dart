import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../providers/routine_provider.dart';
import '../../theme/orbit_tokens.dart';
import '../../widgets/common/premium_glass_card.dart';

class BookmarkedWisdomScreen extends StatelessWidget {
  const BookmarkedWisdomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final routineProvider = context.watch<RoutineProvider>();
    final quotes = routineProvider.bookmarkedQuotes;

    return Scaffold(
      backgroundColor: OrbitTokens.ground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Bookmarked Wisdom',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: quotes.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bookmark_border_rounded,
                      size: 64,
                      color: Colors.white24,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No bookmarked wisdom yet.\nTap the bookmark icon on a scroll to save it here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              physics: const BouncingScrollPhysics(),
              itemCount: quotes.length,
              itemBuilder: (context, index) {
                final quote = quotes[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: PremiumGlassCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            quote,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontFamily: 'Courier',
                              height: 1.5,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.bookmark_remove_rounded,
                            color: OrbitTokens.teal,
                          ),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            routineProvider.toggleBookmark(quote);
                          },
                        ),
                      ],
                    ),
                  ).animate().fade(delay: (index * 50).ms).slideX(begin: 0.1),
                );
              },
            ),
    );
  }
}
