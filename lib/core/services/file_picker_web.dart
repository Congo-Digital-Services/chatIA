import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'file_picker_base.dart';

class FilePickerWeb extends FilePickerPlatform {
  @override
  Future<PickedFileInfo?> pickFile() => pickImage(useCamera: false);

  @override
  Future<PickedFileInfo?> pickImage({required bool useCamera}) {
    return _pickFromInput('image/*');
  }

  @override
  Future<PickedFileInfo?> pickAudioFile() {
    return _pickFromInput('audio/*');
  }

  Future<PickedFileInfo?> _pickFromInput(String accept) async {
    final completer = Completer<PickedFileInfo?>();

    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = accept;
    uploadInput.click();

    uploadInput.onChange.listen((e) async {
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
        final fileBytes = await _readFileBytes(file);
        final dimensions = isImage ? await _readImageDimensions(url) : null;

        completer.complete(
          PickedFileInfo(
            name: name,
            url: url,
            size: sizeStr,
            isImage: isImage,
            bytes: fileBytes,
            mimeType: file.type,
            width: dimensions?.width,
            height: dimensions?.height,
          ),
        );
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

  Future<Uint8List> _readFileBytes(html.File file) {
    final completer = Completer<Uint8List>();
    final reader = html.FileReader();

    reader.onLoad.first.then((_) {
      final result = reader.result;
      if (result is ByteBuffer) {
        completer.complete(result.asUint8List());
      } else if (result is Uint8List) {
        completer.complete(result);
      } else {
        completer.complete(Uint8List(0));
      }
    });

    reader.onError.first.then((_) {
      completer.complete(Uint8List(0));
    });

    reader.readAsArrayBuffer(file);
    return completer.future;
  }

  Future<_ImageDimensions?> _readImageDimensions(String url) {
    final completer = Completer<_ImageDimensions?>();
    final image = html.ImageElement(src: url);

    image.onLoad.first.then((_) {
      completer.complete(
        _ImageDimensions(
          width: image.naturalWidth,
          height: image.naturalHeight,
        ),
      );
    });

    image.onError.first.then((_) {
      completer.complete(null);
    });

    return completer.future;
  }
}

FilePickerPlatform getFilePicker() => FilePickerWeb();

class _ImageDimensions {
  const _ImageDimensions({required this.width, required this.height});

  final int width;
  final int height;
}
