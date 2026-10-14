import 'dart:io';

Future<void> openExternalUrl(String url) async {
  final uri = Uri.parse(url);
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    throw ArgumentError('Chỉ mở đường dẫn HTTP hoặc HTTPS.');
  }
  // No shell: OAuth query strings contain ampersands and must stay one argument.
  final result = Platform.isWindows
      ? await Process.run('rundll32.exe', ['url.dll,FileProtocolHandler', url])
      : await Process.run(Platform.isMacOS ? 'open' : 'xdg-open', [url]);
  if (result.exitCode != 0) {
    throw StateError('Không mở được trình duyệt hệ thống.');
  }
}
