import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.palette,
    this.selectedColor,
    this.onPaletteColorSelected,
    this.segmentedValues,
    this.selectedSegmentIndex,
    this.onSegmentChanged,
    this.onTap,
    this.note,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final IconData? trailing;
  final List<Color>? palette;
  final Color? selectedColor;
  final ValueChanged<Color>? onPaletteColorSelected;
  final List<String>? segmentedValues;
  final int? selectedSegmentIndex;
  final ValueChanged<int>? onSegmentChanged;
  final VoidCallback? onTap;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget tileContent = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.24)
            : AppThemeColors.card.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppThemeColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppThemeColors.pillSelected
                      : AppThemeColors.pill,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: AppThemeColors.textStrong),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppThemeColors.textStrong,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppThemeColors.textSoft,
                      ),
                    ),
                  ],
                ),
              ),
              if (palette != null)
                Row(
                  children: palette!.map((color) {
                    final isSelected =
                        selectedColor?.toARGB32() == color.toARGB32();
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: GestureDetector(
                        onTap: () {
                          if (onPaletteColorSelected != null) {
                            onPaletteColorSelected!(color);
                          }
                        },
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppThemeColors.textStrong
                                  : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.4),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                )
              else if (trailing != null)
                Icon(trailing, size: 24, color: AppThemeColors.textSoft),
            ],
          ),
          if (segmentedValues != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppThemeColors.pill,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < segmentedValues!.length; i++)
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (onSegmentChanged != null) {
                            onSegmentChanged!(i);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: (selectedSegmentIndex ?? 0) == i
                                ? (isDark
                                      ? AppThemeColors.pillSelected
                                      : AppThemeColors.card)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow:
                                (selectedSegmentIndex ?? 0) == i && !isDark
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            segmentedValues![i],
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppThemeColors.textStrong,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (note != null)
              Text(
                note!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppThemeColors.textSoft,
                  height: 1.5,
                ),
              ),
          ],
        ],
      ),
    );

    if (onTap != null && palette == null && segmentedValues == null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: tileContent,
        ),
      );
    }

    return tileContent;
  }
}
