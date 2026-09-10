import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/loading_indicator.dart';
import '../../providers/discovery_provider.dart';
import 'widgets/swipe_card.dart';

class DiscoveryScreen extends ConsumerWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(discoveryControllerProvider);
    final controller = ref.read(discoveryControllerProvider.notifier);

    ref.listen(discoveryControllerProvider, (previous, next) {
      if (next.newMatch != null) {
        _showMatchDialog(context, () => controller.dismissMatchOverlay());
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Découvrir')),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: state.isLoading
            ? const LoadingIndicator()
            : state.error != null
                ? ErrorView(
                    error: state.error!,
                    onRetry: controller.loadCandidates,
                  )
                : state.candidates.isEmpty
                    ? _EmptyState(onRefresh: controller.loadCandidates)
                    : Column(
                        children: [
                          Expanded(
                            child: CardSwiper(
                              cardsCount: state.candidates.length,
                              numberOfCardsDisplayed:
                                  state.candidates.length < 2 ? 1 : 2,
                              onSwipe:
                                  (previousIndex, currentIndex, direction) {
                                final candidate =
                                    state.candidates[previousIndex];
                                controller.swipe(
                                  candidate,
                                  liked: direction == CardSwiperDirection.right,
                                );
                                return true;
                              },
                              cardBuilder: (context, index, _, __) =>
                                  SwipeCard(profile: state.candidates[index]),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _SwipeActionButtons(
                            onPass: () {
                              if (state.candidates.isNotEmpty) {
                                controller.swipe(state.candidates.first,
                                    liked: false);
                              }
                            },
                            onLike: () {
                              if (state.candidates.isNotEmpty) {
                                controller.swipe(state.candidates.first,
                                    liked: true);
                              }
                            },
                          ),
                        ],
                      ),
      ),
    );
  }

  void _showMatchDialog(BuildContext context, VoidCallback onClose) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("C'est un match ! 🎉"),
        content: const Text(
          'Vous vous êtes likés mutuellement. Lancez la conversation dès maintenant !',
        ),
        actions: [
          TextButton(
            onPressed: () {
              onClose();
              Navigator.of(context).pop();
            },
            child: const Text('Continuer à swiper'),
          ),
        ],
      ),
    );
  }
}

class _SwipeActionButtons extends StatelessWidget {
  final VoidCallback onPass;
  final VoidCallback onLike;

  const _SwipeActionButtons({required this.onPass, required this.onLike});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundActionButton(
          icon: Icons.close,
          color: Colors.grey.shade600,
          onPressed: onPass,
        ),
        const SizedBox(width: 24),
        _RoundActionButton(
          icon: Icons.favorite,
          color: Theme.of(context).colorScheme.primary,
          onPressed: onLike,
        ),
      ],
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _RoundActionButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Icon(icon, color: color, size: 28),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 56, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('Plus personne à afficher pour le moment.'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRefresh, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}
