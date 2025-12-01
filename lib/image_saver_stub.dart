import 'dart:typed_data';

// Fallback for platforms sin implementación específica (p.ej. móvil/desktop sin web).
Future<bool> saveBytes(String fileName, Uint8List bytes) async {
  return false;
}
