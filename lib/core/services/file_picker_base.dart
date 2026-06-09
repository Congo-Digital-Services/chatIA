class PickedFileInfo {
  const PickedFileInfo({
    required this.name,
    required this.url,
    required this.size,
    required this.isImage,
  });

  final String name;
  final String url;
  final String size;
  final bool isImage;
}

abstract class FilePickerPlatform {
  Future<PickedFileInfo?> pickFile();
  void openFile(String url);
}
