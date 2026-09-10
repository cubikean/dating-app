import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// Rayon de recherche et partage de position, partagés entre l'inscription et
/// l'édition de profil.
///
/// Le composant ne connaît ni le service de localisation ni les permissions :
/// l'écran qui l'utilise garde la main sur l'appel et sur ses erreurs.
class SearchRadiusField extends StatelessWidget {
  final double radiusKm;
  final bool hasLocation;
  final bool isLocating;
  final ValueChanged<double> onRadiusChanged;
  final VoidCallback onUseMyLocation;

  const SearchRadiusField({
    super.key,
    required this.radiusKm,
    required this.hasLocation,
    required this.isLocating,
    required this.onRadiusChanged,
    required this.onUseMyLocation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Rayon de recherche', style: theme.textTheme.titleSmall),
            Text('${radiusKm.round()} km', style: theme.textTheme.bodyMedium),
          ],
        ),
        Slider(
          value: radiusKm.clamp(
            AppConstants.minSearchRadiusKm,
            AppConstants.maxSearchRadiusKm,
          ),
          min: AppConstants.minSearchRadiusKm,
          max: AppConstants.maxSearchRadiusKm,
          divisions:
              (AppConstants.maxSearchRadiusKm - AppConstants.minSearchRadiusKm)
                  .round(),
          label: '${radiusKm.round()} km',
          onChanged: isLocating ? null : onRadiusChanged,
        ),
        Row(
          children: [
            Icon(
              hasLocation ? Icons.check_circle_outline : Icons.location_off,
              size: 18,
              color: hasLocation
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasLocation
                    ? 'Position enregistrée.'
                    : 'Sans position, le rayon ne filtre rien.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (isLocating)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              TextButton(
                onPressed: onUseMyLocation,
                child: Text(hasLocation ? 'Actualiser' : 'Me localiser'),
              ),
          ],
        ),
      ],
    );
  }
}
