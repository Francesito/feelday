import 'dart:typed_data';

import 'image_saver_stub.dart'
    if (dart.library.html) 'image_saver_web.dart'
    if (dart.library.io) 'image_saver_io.dart';

Future<bool> saveImageBytes(String fileName, Uint8List bytes) {
  return saveBytes(fileName, bytes);
}
