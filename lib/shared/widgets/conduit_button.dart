import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class ConduitPrimaryButton extends StatelessWidget {
  const ConduitPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.white : Colors.black;
    final secondaryColor = isDark ? Colors.black : Colors.white;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          icon == CupertinoIcons.arrow_right_circle_fill
              ? CupertinoIcons.arrow_right_circle_fill
              : icon,
          color: secondaryColor,
        ),
        label: Text(label, style: TextStyle(color: secondaryColor)),
        style: OutlinedButton.styleFrom(
          backgroundColor: primaryColor,
          side: BorderSide(color: primaryColor, width: 1),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class ConduitSecondaryButton extends StatelessWidget {
  const ConduitSecondaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.black : Colors.white;
    final secondaryColor = isDark ? Colors.white : Colors.black;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: secondaryColor,
        ),
        label: Text(label, style: TextStyle(color: secondaryColor)),
        style: OutlinedButton.styleFrom(
          backgroundColor: primaryColor,
          side: BorderSide(color: secondaryColor, width: 1),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}
