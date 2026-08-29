import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ParentAiScreen extends StatelessWidget {
  const ParentAiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Local Wellbeing AI'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.parentAccent, AppTheme.parentPrimary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.lock_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        '100% PRIVATE • ON-DEVICE AI',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Privacy-Preserving On-Device Intelligence',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ClearTime avoids third-party cloud AI APIs. All habit analysis is designed to execute locally on edge hardware.',
                    style: TextStyle(
                      color: Colors.white.withAlpha((0.9 * 255).round()),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Architecture Principles',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            _buildPrincipleCard(
              icon: Icons.cloud_off_rounded,
              title: 'Zero Cloud LLM Dependency',
              description:
                  'No raw conversations or usage telemetry are uploaded to OpenAI, Gemini, or remote inference servers.',
              color: AppTheme.parentSecondary,
            ),
            const SizedBox(height: 12),
            _buildPrincipleCard(
              icon: Icons.memory_rounded,
              title: 'Quantized Edge Inference',
              description:
                  'Utilizes local SLMs running directly on mobile NPU / CPU cores for minimal battery impact and total offline resilience.',
              color: AppTheme.parentAccent,
            ),
            const SizedBox(height: 12),
            _buildPrincipleCard(
              icon: Icons.verified_user_rounded,
              title: 'Encrypted Local Aggregates',
              description:
                  'Usage metrics are stored inside device-encrypted sandbox databases and automatically pruned according to retention rules.',
              color: AppTheme.successGreen,
            ),

            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.check_circle_rounded,
                            color: AppTheme.successGreen, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Local Provider Contract Ready',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'The LocalLLMProvider abstraction is initialized and configured for Phase 2 hardware deployment.',
                      style:
                          TextStyle(color: AppTheme.neutralMuted, fontSize: 13),
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

  Widget _buildPrincipleCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha((0.15 * 255).round()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                        color: AppTheme.neutralMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
