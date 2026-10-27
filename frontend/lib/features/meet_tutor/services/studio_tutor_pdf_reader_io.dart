import 'dart:io';
import 'dart:typed_data';

/// Bounded even if the file grows between stat and reading.
Future<Uint8List?> readTutorPdf(String path, int maxBytes) async {
  final file = File(path);
  if (await file.length() > maxBytes) return null;
  final builder = BytesBuilder(copy: false);
  await for (final chunk in file.openRead(0, maxBytes + 1)) {
    if (builder.length + chunk.length > maxBytes) return null;
    builder.add(chunk);
  }
  return builder.takeBytes();
}
