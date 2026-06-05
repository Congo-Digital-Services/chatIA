import 'package:flutter/material.dart';

import '../../../shared/models/chat_message.dart';
import '../../../shared/theme/app_theme.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F1EF),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Text(
              message.text,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    height: 1.3,
                    color: AppThemeColors.textStrong,
                  ),
            ),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          margin: const EdgeInsets.only(top: 4, right: 10),
          decoration: const BoxDecoration(
            color: Colors.black,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.circle_outlined, size: 12, color: Colors.white),
          ),
        ),
        Expanded(
          child: Text(
            message.text,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  height: 1.42,
                ),
          ),
        ),
      ],
    );
  }
}
