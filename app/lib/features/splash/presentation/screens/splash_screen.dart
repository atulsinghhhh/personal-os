import 'package:flutter/material.dart';

/// Shown for the brief moment while go_router's redirect logic determines
/// whether the restored Supabase session is signed in or not.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
