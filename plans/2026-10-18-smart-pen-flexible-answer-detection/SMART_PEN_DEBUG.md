# Smart Pen debug overlay

Enable the diagnostic overlay in a local Flutter run with:

```powershell
flutter run --dart-define=SMART_PEN_DEBUG=true
```

Colored boxes describe text extraction and classification:

- Gray: extracted text fragment not used as an answer marker (`text_fragment`).
- Green: accepted answer marker (`candidate_accepted`).
- Orange: page-edge marker kept as a partial group (`edge_partial`).
- Red: marker-like text rejected by the classifier. `diagonal_watermark` identifies a likely watermark; `classifier_filter` means the label failed the normal context/group rules.

The candidate label beside each answer also reports its page-link state:

- `local`: an ordinary page-local group.
- `linked`: a unique complementary group was found at the adjacent page edge.
- `unlinked: question_heading`: a nearby numbered question heading blocked the link.
- `unlinked: no_unique_continuation`: no safe unique neighbor was available yet or the evidence was ambiguous.

Text and diagnostic geometry are held only in the debug index and painted in the PDF overlay while this compile-time flag is enabled. The app does not write extracted PDF text to logs. A page with no text layer has no debug fragments and continues to use ordinary pen behavior.
