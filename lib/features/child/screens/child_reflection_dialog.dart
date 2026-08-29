import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/reflection_model.dart';

class ChildReflectionDialog extends StatefulWidget {
  final DailyReflection? existingReflection;
  final ValueChanged<({ReflectionMood mood, String? notes})> onSave;
  final VoidCallback? onDelete;

  const ChildReflectionDialog({
    super.key,
    this.existingReflection,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<ChildReflectionDialog> createState() => _ChildReflectionDialogState();
}

class _ChildReflectionDialogState extends State<ChildReflectionDialog> {
  late ReflectionMood _selectedMood;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedMood = widget.existingReflection?.mood ?? ReflectionMood.productive;
    _notesController.text = widget.existingReflection?.notes ?? '';
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Daily Reflection 🌟',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.childTextDark,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'How did your phone time feel today?',
              style: TextStyle(color: AppTheme.neutralMuted, fontSize: 14),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: ReflectionMood.values.map((mood) {
                final isSelected = _selectedMood == mood;
                return ChoiceChip(
                  label: Text('${mood.emoji} ${mood.label}'),
                  selected: isSelected,
                  selectedColor: AppTheme.childSecondary.withAlpha((0.2 * 255).round()),
                  backgroundColor: AppTheme.neutralBg,
                  labelStyle: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppTheme.childSecondary : AppTheme.childTextDark,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedMood = mood);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: 'What went well? (optional)',
                filled: true,
                fillColor: AppTheme.neutralBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (widget.existingReflection != null && widget.onDelete != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.alertRed),
                    onPressed: () {
                      widget.onDelete!();
                      Navigator.of(context).pop();
                    },
                  ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.childSecondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    widget.onSave((
                      mood: _selectedMood,
                      notes: _notesController.text.trim().isEmpty
                          ? null
                          : _notesController.text.trim(),
                    ));
                    Navigator.of(context).pop();
                  },
                  child: const Text('Save Locally'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
