import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';

Future<bool> saveBytes(String fileName, Uint8List bytes) async {
  try {
    final ext = _extension(fileName);
    final name = ext.isEmpty ? fileName : fileName.replaceAll(RegExp('\\.$ext\$'), '');
    await FileSaver.instance.saveFile(
      name: name,
      bytes: bytes,
      ext: ext,
      mimeType: _mimeFromExt(ext),
    );
    return true;
  } catch (_) {
    return false;
  }
}

String _extension(String fileName) {
  final match = RegExp(r'\.([A-Za-z0-9]+)$').firstMatch(fileName);
  return match?.group(1) ?? 'png';
}

MimeType _mimeFromExt(String ext) {
  final lower = ext.toLowerCase();
  if (lower == 'jpg' || lower == 'jpeg') return MimeType.jpeg;
  if (lower == 'png') return MimeType.png;
  return MimeType.other;
}
