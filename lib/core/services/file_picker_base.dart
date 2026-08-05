import 'dart:typed_data';

class PickedFileInfo {
  const PickedFileInfo({
    required this.name,
    required this.url,
    required this.size,
    required this.isImage,
    this.bytes,
    this.mimeType,
    this.width,
    this.height,
  });

  final String name;
  final String url;
  final String size;
  final bool isImage;
  final Uint8List? bytes;
  final String? mimeType;
  final int? width;
  final int? height;
}

abstract class FilePickerPlatform {
  /// Image depuis la galerie (comportement historique).
  Future<PickedFileInfo?> pickFile();

  /// Photo : caméra (`useCamera: true`) ou galerie (`useCamera: false`).
  Future<PickedFileInfo?> pickImage({required bool useCamera});

  /// Fichier audio.
  Future<PickedFileInfo?> pickAudioFile();

  void openFile(String url);
}
