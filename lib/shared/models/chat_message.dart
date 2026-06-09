enum ChatRole { user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    this.fileUrl,
    this.fileName,
    this.fileSize,
    this.isImage,
    this.audioUrl,
  });

  final String id;
  final ChatRole role;
  final String text;
  final String? fileUrl;
  final String? fileName;
  final String? fileSize;
  final bool? isImage;
  final String? audioUrl;

  const ChatMessage.user({
    required String id,
    required String text,
    String? fileUrl,
    String? fileName,
    String? fileSize,
    bool? isImage,
    String? audioUrl,
  }) : this(
          id: id,
          role: ChatRole.user,
          text: text,
          fileUrl: fileUrl,
          fileName: fileName,
          fileSize: fileSize,
          isImage: isImage,
          audioUrl: audioUrl,
        );

  const ChatMessage.assistant({
    required String id,
    required String text,
    String? fileUrl,
    String? fileName,
    String? fileSize,
    bool? isImage,
    String? audioUrl,
  }) : this(
          id: id,
          role: ChatRole.assistant,
          text: text,
          fileUrl: fileUrl,
          fileName: fileName,
          fileSize: fileSize,
          isImage: isImage,
          audioUrl: audioUrl,
        );
}
