import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ChildAiScreen extends StatelessWidget {
  const ChildAiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.childSurface,
      appBar: AppBar(
        backgroundColor: AppTheme.childSurface,
        title: const Text('My Wellbeing Buddy 🤖'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.neutralBorder),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.childSecondary
                          .withAlpha((0.15 * 255).round()),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.smart_toy_rounded,
                      size: 44,
                      color: AppTheme.childSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Hey there! I am your On-Device Buddy.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.childTextDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'I live right on your phone without sending any of your personal info or chat to outside servers.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: AppTheme.neutralMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          AppTheme.successGreen.withAlpha((0.15 * 255).round()),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_rounded,
                            color: AppTheme.successGreen, size: 16),
                        SizedBox(width: 6),
                        Text(
                          '100% Offline & Private',
                          style: TextStyle(
                            color: AppTheme.successGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Friendly Encouragement',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '"Great job on taking an outdoor sunlight break today! Keep up the awesome momentum."',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: AppTheme.childTextDark,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
