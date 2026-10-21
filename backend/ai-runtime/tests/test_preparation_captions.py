import sys
from pathlib import Path
import pytest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from preparation_render import reviewed_cues, srt_time
from preparation_worker import validate_scenes


def scene():
    return {'id': 'scene-a', 'title': 'Water', 'text': 'Water', 'narration': 'Water rises.',
            'captionsReviewed': True, 'captionsNarration': 'Water rises.',
            'captions': [{'id': 'cue-a', 'start': .2, 'end': 1.8, 'text': 'Edited caption.'}]}


def test_reviewed_caption_text_and_timing_survive_scene_projection():
    projected = validate_scenes([scene()])[0]
    assert reviewed_cues(projected, 2) == [(.2, 1.8, 'Edited caption.')]
    assert srt_time(28.44 + .2) == '00:00:28,640'


@pytest.mark.parametrize('mutate', [
    lambda s: s.update(narration='Changed script.'),
    lambda s: s['captions'][0].update(end=2.5),
    lambda s: s['captions'][0].update(start=-1),
    lambda s: s['captions'][0].update(end=float('nan')),
    lambda s: s['captions'].append({'id': 'cue-b', 'start': 1, 'end': 1.9, 'text': 'Overlap'}),
])
def test_stale_or_out_of_bounds_reviewed_captions_are_not_silently_rendered(mutate):
    value = scene()
    mutate(value)
    with pytest.raises(ValueError):
        reviewed_cues(value, 2)


def test_bilingual_captions_preserve_secondary_text_and_visibility():
    value = scene()
    value.update(captionMode='bilingual', captionsVisible=False)
    value['captions'][0]['secondaryText'] = 'Nước bốc lên.'
    projected = validate_scenes([value])[0]
    assert projected['captionsVisible'] is False
    assert reviewed_cues(projected, 2) == [(.2, 1.8, 'Edited caption.\nNước bốc lên.')]
    assert projected['captions'][0]['id'] == 'cue-a'


def test_bilingual_requires_teacher_secondary_text():
    value = scene()
    value['captionMode'] = 'bilingual'
    with pytest.raises(ValueError, match='secondary'):
        reviewed_cues(value, 2)


@pytest.mark.parametrize('field,value', [('captionMode', 'unknown'), ('captionsVisible', 'false')])
def test_caption_presentation_rejects_unknown_values(field, value):
    item = scene()
    item[field] = value
    with pytest.raises(ValueError):
        validate_scenes([item])
