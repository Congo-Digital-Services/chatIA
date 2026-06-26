import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import 'file_picker_base.dart';

class FilePickerMobile extends FilePickerPlatform {
  final _picker = ImagePicker();

  @override
  Future<PickedFileInfo?> pickFile() async {
    // Propose galerie + caméra via une sélection image_picker
    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90, // légère compression pour réduire la taille
    );

    if (picked == null) return null;

    try {
      final Uint8List bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return null;

      // Lire les dimensions de l'image
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final width = frame.image.width;
      final height = frame.image.height;
      frame.image.dispose();

      // Calculer taille lisible
      final sizeLabel = _humanSize(bytes.length);

      // Type MIME
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
  void openFile(String url) {
    // Sur mobile, on peut ouvrir le fichier avec le système
    // Pour l'instant, pas d'action nécessaire — l'image est affichée dans le chat
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
