enum ChatRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
  });

  final String id;
  final ChatRole role;
  final String text;

  const ChatMessage.user({
    required String id,
    required String text,
  }) : this(id: id, role: ChatRole.user, text: text);

  const ChatMessage.assistant({
    required String id,
    required String text,
  }) : this(id: id, role: ChatRole.assistant, text: text);
}
