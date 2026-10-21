Future<void> launchAudienceWindow({
  required String base,
  required String token,
  required String id,
  required void Function() onExit,
}) async {
  throw UnsupportedError('Cửa sổ trình chiếu riêng cần bản Windows native.');
}

Future<void> closeAudienceWindow() async {}
Map<String, String> audienceEnvironment() => {};
