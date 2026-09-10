import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// Sélecteur de tranche d'âge recherchée, partagé entre l'inscription et
/// l'édition de profil pour que les deux écrans restent d'accord sur les
/// bornes et sur la formulation.
class AgeRangeField extends StatelessWidget {
  final int ageMin;
  final int ageMax;
  final void Function(int ageMin, int ageMax) onChanged;

  const AgeRangeField({
    super.key,
    required this.ageMin,
    required this.ageMax,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Tranche d'âge recherchée",
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              '$ageMin – $ageMax ans',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        RangeSlider(
          values: RangeValues(ageMin.toDouble(), ageMax.toDouble()),
          min: AppConstants.minAge.toDouble(),
          max: AppConstants.maxAge.toDouble(),
          divisions: AppConstants.maxAge - AppConstants.minAge,
          labels: RangeLabels('$ageMin', '$ageMax'),
          onChanged: (values) =>
              onChanged(values.start.round(), values.end.round()),
        ),
      ],
    );
  }
}
