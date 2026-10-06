import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/home/presentation/home_page.dart';

class VenueVaultApp extends StatelessWidget {
  const VenueVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VenueVault',
      theme: AppTheme.light,
      home: const HomePage(),
    );
  }
}
