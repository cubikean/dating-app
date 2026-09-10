import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../models/user_profile.dart';

/// Carte de profil affichée dans la pile swipeable. Purement présentationnel
/// — la logique de swipe/like vit dans `DiscoveryController`.
class SwipeCard extends StatelessWidget {
  final UserProfile profile;

  const SwipeCard({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = profile.photoUrls.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasPhoto)
            CachedNetworkImage(
              imageUrl: profile.photoUrls.first,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest),
              errorWidget: (context, url, error) => _fallbackAvatar(context),
            )
          else
            _fallbackAvatar(context),

          // Dégradé pour garder le texte lisible sur la photo.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),
          ),

          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${profile.name}, ${profile.age}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                if (profile.bio.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    profile.bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
                if (profile.interests.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: profile.interests.take(4).map((interest) {
                      return Chip(
                        label: Text(interest,
                            style: const TextStyle(fontSize: 12)),
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        labelStyle: const TextStyle(color: Colors.white),
                        side: BorderSide.none,
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: const Center(
        child: Icon(Icons.person, size: 96, color: Colors.white70),
      ),
    );
  }
}
