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
  Future<PickedFileInfo?> pickFile();
  void openFile(String url);
}
