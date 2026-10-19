import 'package:web/web.dart' as web;

void publishProfileMetrics(String metrics) {
  web.document.title = 'SMART_PEN_RUNTIME_PROFILE=$metrics';
}
