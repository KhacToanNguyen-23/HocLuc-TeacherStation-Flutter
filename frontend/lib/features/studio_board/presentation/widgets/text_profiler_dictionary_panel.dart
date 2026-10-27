import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/models/dynamic_dictionary_entry.dart';
import '../../domain/models/text_profile_models.dart';
import '../../services/profiler/dictionary_enrichment_controller.dart';

class TextProfilerDictionaryPanel extends StatelessWidget {
  final WordTokenInfo token;
  final String passageId;
  final DictionaryEnrichmentController controller;

  const TextProfilerDictionaryPanel({
    super.key,
    required this.token,
    required this.passageId,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final entry = controller.entryFor(passageId, token.lemma);
    final status = controller.statusFor(passageId, token.lemma);
    final isPending = status == DictionaryEnrichmentStatus.pending;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x18000000),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x2889b4fa)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    color: Color(0xff86efac),
                    size: 15,
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Dictionary metadata · CEFR remains Unknown',
                      style: TextStyle(
                        color: Color(0xff86efac),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  key: const Key('dictionary-manual-action'),
                  onPressed: isPending
                      ? null
                      : () => unawaited(
                          controller.lookupManually(
                            passageId,
                            token.lemma,
                            forceRefresh: true,
                          ),
                        ),
                  icon: Icon(
                    entry == null ? Icons.search : Icons.refresh,
                    size: 14,
                  ),
                  label: Text(
                    isPending
                        ? 'Looking up…'
                        : entry == null
                        ? 'Look up dictionary entry'
                        : 'Refresh dictionary entry',
                    style: const TextStyle(fontSize: 10.5),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xff89b4fa),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
          ),
          if (isPending) ...[
            const SizedBox(height: 4),
            const LinearProgressIndicator(minHeight: 2),
          ],
          if (status == DictionaryEnrichmentStatus.failed) ...[
            const SizedBox(height: 4),
            const Text(
              'Lookup failed. You can try again.',
              style: TextStyle(color: Color(0xfffca5a5), fontSize: 10.5),
            ),
          ],
          if (entry != null) ..._buildEntryDetails(entry),
          if (entry == null &&
              !isPending &&
              status == DictionaryEnrichmentStatus.notFound) ...[
            const SizedBox(height: 4),
            const Text(
              'No cached dictionary entry. You can look it up manually.',
              style: TextStyle(color: Color(0xffa6adc8), fontSize: 10.5),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildEntryDetails(DynamicDictionaryEntry entry) {
    final details = <Widget>[];
    for (final phonetic in entry.phonetics) {
      if (phonetic.text.isNotEmpty) {
        details.add(
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              phonetic.text,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ),
        );
      }
    }
    for (final meaning in entry.meanings) {
      if (meaning.partOfSpeech.isNotEmpty) {
        details.add(
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              meaning.partOfSpeech,
              style: const TextStyle(
                color: Color(0xff89b4fa),
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      }
      for (final definition in meaning.definitions) {
        if (definition.definition.isEmpty) continue;
        details.add(
          Padding(
            padding: const EdgeInsets.only(top: 3, left: 8),
            child: Text(
              '• ${definition.definition}',
              style: const TextStyle(color: Colors.white, fontSize: 10.5),
            ),
          ),
        );
        if (definition.example?.isNotEmpty ?? false) {
          details.add(
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 16),
              child: Text(
                '“${definition.example}”',
                style: const TextStyle(
                  color: Color(0xffa6adc8),
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          );
        }
      }
    }
    if (details.isEmpty) {
      details.add(
        const Padding(
          padding: EdgeInsets.only(top: 5),
          child: Text(
            'No pronunciation or definition details are available.',
            style: TextStyle(color: Color(0xffa6adc8), fontSize: 10.5),
          ),
        ),
      );
    }
    return details;
  }
}
