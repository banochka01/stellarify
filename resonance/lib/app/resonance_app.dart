import 'package:flutter/material.dart';
import 'package:resonance/app/router.dart';
import 'package:resonance/shared/theme/resonance_theme.dart';

class ResonanceApp extends StatelessWidget {
  const ResonanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Resonance',
      debugShowCheckedModeBanner: false,
      theme: ResonanceTheme.dark,
      routerConfig: resonanceRouter,
    );
  }
}
