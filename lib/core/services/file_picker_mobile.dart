import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart' hide FilePickerPlatform;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'file_picker_base.dart';

class FilePickerMobile extends FilePickerPlatform {
  final _picker = ImagePicker();

  @override
  Future<PickedFileInfo?> pickFile() => pickImage(useCamera: false);

  @override
  Future<PickedFileInfo?> pickImage({required bool useCamera}) async {
    final XFile? picked = await _picker.pickImage(
      source: useCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 90,
    );

    if (picked == null) return null;

    try {
      final Uint8List bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return null;

      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final width = frame.image.width;
      final height = frame.image.height;
      frame.image.dispose();

      final sizeLabel = _humanSize(bytes.length);
      final ext = picked.name.split('.').last.toLowerCase();
      final mimeType = _mimeFromExt(ext);

      return PickedFileInfo(
        name: picked.name,
        url: picked.path,
        size: sizeLabel,
        isImage: true,
        bytes: bytes,
        mimeType: mimeType,
        width: width,
        height: height,
      );
    } catch (e) {
      debugPrint('[FilePickerMobile] Erreur lors de la lecture de l\'image : $e');
      return null;
    }
  }

  @override
  Future<PickedFileInfo?> pickAudioFile() async {
    final result = await FilePicker.pickFiles(type: FileType.audio);
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final picked = result.files.first;
    final name = picked.name;
    var bytes = picked.bytes;
    if (bytes == null && picked.path != null) {
      try {
        final file = File(picked.path!);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        }
      } catch (e) {
        debugPrint('[FilePickerMobile] Erreur lecture audio : $e');
      }
    }

    final sizeLabel = bytes != null ? _humanSize(bytes.length) : picked.size.toString();

    return PickedFileInfo(
      name: name,
      url: picked.path ?? name,
      size: sizeLabel,
      isImage: false,
      bytes: bytes,
      mimeType: 'audio/${_audioExt(name)}',
    );
  }

  String _audioExt(String name) {
    final ext = name.split('.').last.toLowerCase();
    const audioExts = {
      'm4a': 'mp4',
      'aac': 'aac',
      'mp3': 'mpeg',
      'wav': 'wav',
      'ogg': 'ogg',
      'oga': 'ogg',
      'opus': 'ogg',
      'flac': 'flac',
      'amr': 'amr',
    };
    return audioExts[ext] ?? ext;
  }

  @override
  void openFile(String url) {
    debugPrint('[FilePickerMobile] openFile: $url');
  }

  String _humanSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _mimeFromExt(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      default:
        return 'image/$ext';
    }
  }
}

FilePickerPlatform getFilePicker() => FilePickerMobile();
