import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ChildInsightsScreen extends StatelessWidget {
  const ChildInsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.childSurface,
      appBar: AppBar(
        backgroundColor: AppTheme.childSurface,
        title: const Text('Wellbeing Insights 💡'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.neutralBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.emoji_objects_rounded,
                        color: AppTheme.childAccent, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Tip of the Day',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'The 20-20-20 Rule: Every 20 minutes spent looking at a screen, look at something 20 feet away for 20 seconds. It gives your eyes a super recharge!',
                  style: TextStyle(
                      color: AppTheme.childTextDark, fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Healthy Digital Habits',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.childTextDark,
                ),
          ),
          const SizedBox(height: 12),
          _buildInsightCard(
            icon: Icons.timer_outlined,
            title: 'Mindful Breaks',
            description:
                'Taking quick 5-minute pauses between games keeps your brain sharp and energized.',
            badge: 'Top Habit',
            color: AppTheme.childSecondary,
          ),
          const SizedBox(height: 12),
          _buildInsightCard(
            icon: Icons.menu_book_rounded,
            title: 'Deep Focus Sprints',
            description:
                'Turning off notifications while doing homework helps you finish 30% faster.',
            badge: 'Focus Booster',
            color: AppTheme.childPrimary,
          ),
          const SizedBox(height: 12),
          _buildInsightCard(
            icon: Icons.bedtime_outlined,
            title: 'Sleep Friendly Nights',
            description:
                'Putting your phone away 30 minutes before sleep helps you wake up refreshed.',
            badge: 'Night Recharge',
            color: AppTheme.warningOrange,
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard({
    required IconData icon,
    required String title,
    required String description,
    required String badge,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withAlpha((0.15 * 255).round()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                  color: AppTheme.neutralMuted, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
