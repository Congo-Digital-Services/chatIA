import 'package:flutter/material.dart';

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.palette,
    this.segmentedValues,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final IconData? trailing;
  final List<Color>? palette;
  final List<String>? segmentedValues;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE3E4DF)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E3DE),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontSize: 19,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: const Color(0xFF5F635B),
                          ),
                    ),
                  ],
                ),
              ),
              if (palette != null)
                Row(
                  children: palette!
                      .map(
                        (color) => Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                )
              else if (trailing != null)
                Icon(trailing, size: 26),
            ],
          ),
          if (segmentedValues != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFDFE0DC),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < segmentedValues!.length; i++)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: i == 0 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          segmentedValues![i],
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Keep audio on this device. Voice input stops working if on-device speech recognition isn’t supported.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45),
            ),
          ],
        ],
      ),
    );
  }
}
