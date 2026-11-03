import 'dart:io';
import 'dart:async';

import 'package:english_assistant_engine/english_assistant_engine.dart';

Future<void> main(List<String> args) async {
  final port = _resolvePort(args, Platform.environment['HOCLUC_PLUGIN_PORT']);
  if (port == null) {
    stderr.writeln('A valid --port or HOCLUC_PLUGIN_PORT is required.');
    exitCode = 64;
    return;
  }

  final server = AnalysisHttpServer();
  try {
    final boundPort = await server.start(port: port);
    stdout.writeln(
      'English Assistant analysis API listening on 127.0.0.1:$boundPort',
    );
    // HttpServer has no portable signal watcher on Windows. Keep the process
    // alive while the listener is active; the host owns process teardown.
    await Completer<void>().future;
  } on SocketException {
    stderr.writeln('Could not bind the local analysis API.');
    exitCode = 70;
  } finally {
    await server.close();
  }
}

int? _resolvePort(List<String> args, String? environmentPort) {
  int? cliPort;
  for (var i = 0; i < args.length; i++) {
    if (args[i] != '--port' || i + 1 >= args.length || cliPort != null) {
      return null;
    }
    cliPort = int.tryParse(args[++i]);
  }
  final port = cliPort ?? int.tryParse(environmentPort ?? '');
  if (port == null || port < 1 || port > 65535) return null;
  return port;
}
