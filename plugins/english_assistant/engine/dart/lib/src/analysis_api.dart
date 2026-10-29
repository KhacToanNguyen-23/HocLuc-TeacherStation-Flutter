import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'english_assistant_profiler.dart';
import 'grammar_collocation.dart';

class EnglishAssistantAnalysisApi {
  final GrammarRuleAnalyzer grammarAnalyzer;
  final CollocationAnalyzer collocationAnalyzer;

  EnglishAssistantAnalysisApi({
    GrammarRuleAnalyzer? grammarAnalyzer,
    CollocationAnalyzer? collocationAnalyzer,
  }) : grammarAnalyzer = grammarAnalyzer ?? GrammarRuleAnalyzer(),
       collocationAnalyzer = collocationAnalyzer ?? CollocationAnalyzer();

  Map<String, Object?> analyze(Map<String, Object?> json) {
    final analysis = EnglishAssistantProfiler.analyzeJson(json);
    final selectionToken = json['selectionToken'];
    if (analysis.status != 'complete') {
      return {
        ...analysis.toJson(),
        if (selectionToken is String) 'selectionToken': selectionToken,
        'spans': const <Object?>[],
      };
    }

    final spans =
        <Map<String, Object?>>[
          ...analysis.tokens.map((token) {
            final lexical = token.lexicalInfo;
            final level = lexical.cefrLevel.toUpperCase();
            final pedagogical =
                lexical.isAcademic || const {'B2', 'C1', 'C2'}.contains(level);
            return <String, Object?>{
              'start': token.start,
              'end': token.end,
              'text': token.surface,
              'offsetUnit': 'unicodeCodePoint',
              'style': {
                'id': 'vocabulary',
                'metadata': {
                  'category': 'vocabulary',
                  'level': level,
                  'label': 'CEFR $level',
                  'note': lexical.isRecognizedUnrated
                      ? 'Recognized, but no verified CEFR level is available.'
                      : lexical.frequencyBand,
                  'lemma': lexical.lemma,
                  'pos': lexical.pos,
                  'isAcademic': lexical.isAcademic,
                  'isPedagogical': pedagogical,
                  'isPreTeach': pedagogical,
                  'isProperNoun': lexical.isProperNoun,
                  'isNumber': lexical.isNumber,
                  'isFunctionWord': false,
                  'lexicalStatus': lexical.lexicalStatus.name,
                  'frequencyBand': lexical.frequencyBand,
                  'academicMetricLevel': lexical.academicMetricLevel,
                },
              },
            };
          }),
          ...grammarAnalyzer
              .analyze(analysis.sourceText)
              .map(
                (match) => {
                  'start': match.start,
                  'end': match.end,
                  'text': match.text,
                  'offsetUnit': 'unicodeCodePoint',
                  'style': {
                    'id': 'grammar',
                    'metadata': {
                      'category': match.category,
                      'ruleId': match.ruleId,
                      'label': match.name,
                      'description': match.description,
                      'note': match.note,
                      'color': match.color,
                      'example': match.example,
                    },
                  },
                },
              ),
          ...collocationAnalyzer
              .analyze(analysis.sourceText)
              .map(
                (match) => {
                  'start': match.start,
                  'end': match.end,
                  'text': match.text,
                  'offsetUnit': 'unicodeCodePoint',
                  'style': {
                    'id': 'collocation',
                    'metadata': {
                      'category': match.category,
                      'label': match.type,
                      'note': match.explanation,
                      'color': match.color,
                      'example': match.text,
                    },
                  },
                },
              ),
        ]..sort((left, right) {
          final startOrder = (left['start']! as int).compareTo(
            right['start']! as int,
          );
          return startOrder != 0
              ? startOrder
              : (right['end']! as int).compareTo(left['end']! as int);
        });

    final result = analysis.toJson();
    return {
      ...result,
      if (selectionToken is String) 'selectionToken': selectionToken,
      'spans': spans,
      'diagnostics': [
        ...analysis.diagnostics,
        if (GrammarRuleAnalyzer.unsupportedRules.isNotEmpty)
          'Parser-dependent rules are unsupported: '
              '${GrammarRuleAnalyzer.unsupportedRules.join(', ')}.',
      ],
    };
  }
}

class AnalysisHttpServer {
  static const maxRequestBytes = 1024 * 1024;
  static const maxTextCodeUnits = 200000;

  final EnglishAssistantAnalysisApi api;
  HttpServer? _server;

  AnalysisHttpServer({EnglishAssistantAnalysisApi? api})
    : api = api ?? EnglishAssistantAnalysisApi();

  int? get port => _server?.port;

  Future<int> start({int port = 0}) async {
    if (_server != null) return _server!.port;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    _server!.listen(_handleRequest);
    return _server!.port;
  }

  Future<void> close({bool force = true}) async {
    final server = _server;
    _server = null;
    await server?.close(force: force);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    final response = request.response;
    response.headers
      ..set(HttpHeaders.accessControlAllowOriginHeader, '*')
      ..set(HttpHeaders.accessControlAllowMethodsHeader, 'GET, POST, OPTIONS')
      ..set(HttpHeaders.accessControlAllowHeadersHeader, 'Content-Type');

    if (request.method == 'OPTIONS' && request.uri.path == '/api/analyze') {
      response.statusCode = HttpStatus.noContent;
      await response.close();
      return;
    }
    if (request.method == 'GET' && request.uri.path == '/health') {
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode({'status': 'ok', 'schemaVersion': 1}));
      await response.close();
      return;
    }
    if (request.uri.path != '/api/analyze') {
      await _writeError(response, HttpStatus.notFound, 'route_not_found');
      return;
    }
    if (request.method != 'POST') {
      await _writeError(
        response,
        HttpStatus.methodNotAllowed,
        'method_not_allowed',
      );
      return;
    }
    if ((request.contentLength) > maxRequestBytes) {
      await _writeError(
        response,
        HttpStatus.requestEntityTooLarge,
        'request_too_large',
      );
      return;
    }

    final body = BytesBuilder(copy: false);
    try {
      await for (final chunk in request) {
        if (body.length + chunk.length > maxRequestBytes) {
          await _writeError(
            response,
            HttpStatus.requestEntityTooLarge,
            'request_too_large',
          );
          return;
        }
        body.add(chunk);
      }
      final decoded = jsonDecode(utf8.decode(body.takeBytes()));
      if (decoded is! Map) {
        await _writeError(
          response,
          HttpStatus.badRequest,
          'invalid_json_object',
        );
        return;
      }
      final input = Map<String, Object?>.from(decoded);
      final source = input['source'];
      if (source is Map && source['text'] is String) {
        final text = source['text']! as String;
        if (text.length > maxTextCodeUnits) {
          await _writeError(
            response,
            HttpStatus.requestEntityTooLarge,
            'text_too_large',
          );
          return;
        }
      }
      final result = api.analyze(input);
      final status = result['status'] == 'complete'
          ? HttpStatus.ok
          : HttpStatus.badRequest;
      response.statusCode = status;
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode(result));
      await response.close();
    } on FormatException {
      await _writeError(response, HttpStatus.badRequest, 'invalid_json');
    } catch (_) {
      await _writeError(
        response,
        HttpStatus.internalServerError,
        'analysis_failed',
      );
    }
  }

  Future<void> _writeError(
    HttpResponse response,
    int statusCode,
    String code,
  ) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode({'status': 'error', 'error': code}));
    await response.close();
  }
}
