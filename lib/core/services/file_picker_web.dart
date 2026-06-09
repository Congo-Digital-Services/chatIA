import 'dart:async';
import 'dart:html' as html;
import 'file_picker_base.dart';

class FilePickerWeb extends FilePickerPlatform {
  @override
  Future<PickedFileInfo?> pickFile() async {
    final completer = Completer<PickedFileInfo?>();

    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = 'image/*,application/pdf,text/*,audio/*,video/*';
    uploadInput.click();

    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files != null && files.isNotEmpty) {
        final file = files.first;
        final name = file.name;
        final bytes = file.size;
        
        // Format size
        String sizeStr;
        if (bytes < 1024) {
          sizeStr = '$bytes B';
        } else if (bytes < 1024 * 1024) {
          sizeStr = '${(bytes / 1024).toStringAsFixed(1)} KB';
        } else {
          sizeStr = '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
        }

        final isImage = file.type.startsWith('image/');
        final url = html.Url.createObjectUrlFromBlob(file);

        completer.complete(PickedFileInfo(
          name: name,
          url: url,
          size: sizeStr,
          isImage: isImage,
        ));
      } else {
        completer.complete(null);
      }
    });

    return completer.future;
  }

  @override
  void openFile(String url) {
    html.window.open(url, '_blank');
  }
}

FilePickerPlatform getFilePicker() => FilePickerWeb();
