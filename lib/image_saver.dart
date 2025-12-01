import 'dart:typed_data';

import 'image_saver_stub.dart'
    if (dart.library.html) 'image_saver_web.dart';

Future<bool> saveImageBytes(String fileName, Uint8List bytes) {
  return saveBytes(fileName, bytes);
}
