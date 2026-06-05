import 'chat_message.dart';

class Conversation {
  const Conversation({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.folder,
    required this.isPinned,
    required this.messages,
    this.heroAssetLabel,
  });

  final String id;
  final String title;
  final String subtitle;
  final String folder;
  final bool isPinned;
  final String? heroAssetLabel;
  final List<ChatMessage> messages;

  Conversation copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? folder,
    bool? isPinned,
    String? heroAssetLabel,
    List<ChatMessage>? messages,
  }) {
    return Conversation(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      folder: folder ?? this.folder,
      isPinned: isPinned ?? this.isPinned,
      heroAssetLabel: heroAssetLabel ?? this.heroAssetLabel,
      messages: messages ?? this.messages,
    );
  }
}
