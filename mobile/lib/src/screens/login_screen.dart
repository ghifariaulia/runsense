import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, required this.error, required this.onConnect});

  final String? error;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('STRAVA INTELLIGENCE', style: KickerStyle.text),
              const SizedBox(height: 18),
              const Text.rich(
                TextSpan(
                  text: 'Run',
                  children: [
                    TextSpan(
                        text: 'Sense',
                        style: TextStyle(color: AppColors.accent))
                  ],
                ),
                style: TextStyle(
                    fontSize: 84, height: .82, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 24),
              const Text(
                'An AI running coach powered by your Strava data. Honest, data-backed training insights.',
                style: TextStyle(
                    color: AppColors.muted, fontSize: 18, height: 1.45),
              ),
              const SizedBox(height: 32),
              TextButton(
                onPressed: onConnect,
                style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                child: const Text('CONNECT WITH STRAVA',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              if (error != null) ...[
                const SizedBox(height: 18),
                Text(error!, style: const TextStyle(color: AppColors.accent)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
