import 'package:flutter/material.dart';
import 'package:teaching_companion/models/studio_state.dart';
import 'audio_translation_controls.dart';

class AudioTranslationStudioButton extends StatelessWidget {
  const AudioTranslationStudioButton({super.key, required this.studio});
  final StudioState studio;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: const Icon(Icons.translate),
    label: const Text('Dịch giọng nói offline'),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Dịch giọng nói offline',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Đóng',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AudioTranslationControls(
                  audio: studio.audio,
                  onPreferencesChanged: () => studio.change(() {
                    studio.language = studio.audio.language == 'en'
                        ? 'English'
                        : 'Tiếng Việt';
                    studio.denoise = false;
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

