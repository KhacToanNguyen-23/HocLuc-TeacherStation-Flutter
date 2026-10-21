import 'dart:io';

Process? _audienceProcess;
Future<void> launchAudienceWindow({
  required String base,
  required String token,
  required String id,
  required void Function() onExit,
}) async {
  if (!Platform.isWindows) {
    throw UnsupportedError('Cửa sổ trình chiếu riêng cần bản Windows native.');
  }
  await closeAudienceWindow();
  final process = await Process.start(
    Platform.resolvedExecutable,
    ['--audience'],
    environment: {
      'HOC_LUC_AUDIENCE_BASE': base,
      'HOC_LUC_AUDIENCE_TOKEN': token,
      'HOC_LUC_AUDIENCE_ID': id,
      'HOC_LUC_AUDIENCE_TITLE': 'HocLuc Audience $id',
    },
    mode: ProcessStartMode.normal,
  );
  _audienceProcess = process;
  // Drain child pipes so the renderer can never block on its log buffer.
  process.stdout.drain<void>();
  process.stderr.drain<void>();
  process.exitCode.then((_) {
    if (identical(_audienceProcess, process)) {
      _audienceProcess = null;
      onExit();
    }
  });
}

Future<void> closeAudienceWindow() async {
  final process = _audienceProcess;
  _audienceProcess = null;
  process?.kill();
}

Map<String, String> audienceEnvironment() => {
  'base': Platform.environment['HOC_LUC_AUDIENCE_BASE'] ?? '',
  'token': Platform.environment['HOC_LUC_AUDIENCE_TOKEN'] ?? '',
  'id': Platform.environment['HOC_LUC_AUDIENCE_ID'] ?? '',
};
