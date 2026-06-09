import 'file_picker_base.dart';

class FilePickerMobile extends FilePickerPlatform {
  @override
  Future<PickedFileInfo?> pickFile() async {
    // Simulated mock file info for mobile fallback
    return const PickedFileInfo(
      name: 'screenshot_2026.png',
      url: 'assets/mock_image.png',
      size: '240 KB',
      isImage: true,
    );
  }

  @override
  void openFile(String url) {
    // Simulated open
  }
}

FilePickerPlatform getFilePicker() => FilePickerMobile();
