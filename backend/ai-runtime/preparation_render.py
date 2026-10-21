"""Deterministic slide animation renderer. No model-generated code is executed."""
from pathlib import Path
import math
import re
import shutil
from preparation_runtime import atomic_json, run_ffmpeg

WIDTH, HEIGHT, FPS = 1280, 720, 25
FONT = Path(__file__).resolve().parents[2] / 'frontend' / 'assets' / 'fonts' / 'Manrope.ttf'


def wrapped(draw, text, font, width):
    lines = []
    for paragraph in text.splitlines() or [text]:
        line = ''
        for word in paragraph.split():
            if draw.textlength(word, font=font) > width:
                raise ValueError('A scene contains an unbreakable word wider than the slide.')
            proposed = (line + ' ' + word).strip()
            if line and draw.textlength(proposed, font=font) > width:
                lines.append(line)
                line = word
            else:
                line = proposed
        lines.append(line)
    return lines


def draw_scene(scene, destination):
    from PIL import Image, ImageDraw, ImageFont, ImageOps
    Image.MAX_IMAGE_PIXELS = 40_000_000
    if not FONT.is_file():
        raise RuntimeError('Bundled Manrope font is missing.')
    image = Image.new('RGB', (WIDTH, HEIGHT), '#f7fafc')
    draw = ImageDraw.Draw(image)
    title_font = ImageFont.truetype(str(FONT), 42)
    title_lines = wrapped(draw, scene['title'], title_font, 1120)
    if len(title_lines) > 2:
        raise ValueError('Scene title is too long; shorten it before rendering.')
    draw.rectangle((0, 0, WIDTH, 12), fill='#2563eb')
    top = 48
    for line in title_lines:
        draw.text((64, top), line, fill='#10243a', font=title_font)
        top += 55
    top += 24
    right = 1216
    if scene.get('imagePath'):
        with Image.open(scene['imagePath']) as source:
            source.load()
            fitted = ImageOps.contain(source.convert('RGB'), (520, 450))
            image.paste(fitted, (680 + (520 - fitted.width) // 2, top))
        right = 620
    if scene['template'] == 'diagram' and not scene.get('imagePath'):
        nodes = [x.strip() for x in re.split(r'\n|→|->', scene['text']) if x.strip()]
        if not 2 <= len(nodes) <= 5:
            raise ValueError('Diagram template needs 2–5 nodes separated by newlines or arrows.')
        font = ImageFont.truetype(str(FONT), 26)
        width = (1120 - (len(nodes) - 1) * 26) // len(nodes)
        for index, node in enumerate(nodes):
            x = 64 + index * (width + 26)
            lines = wrapped(draw, node, font, width - 24)
            if len(lines) > 7:
                raise ValueError('Diagram node is too long; shorten its label.')
            draw.rounded_rectangle((x, top + 60, x + width, top + 360), radius=14, fill='#dbeafe', outline='#93c5fd', width=2)
            y = top + 85
            for line in lines:
                draw.text((x + 12, y), line, font=font, fill='#10243a')
                y += 34
            if index < len(nodes) - 1:
                arrow_x = x + width + 4
                draw.line((arrow_x, top + 210, arrow_x + 18, top + 210), fill='#2563eb', width=3)
                draw.polygon([(arrow_x + 18, top + 210), (arrow_x + 11, top + 204), (arrow_x + 11, top + 216)], fill='#2563eb')
    else:
        for size in range(34, 19, -2):
            font = ImageFont.truetype(str(FONT), size)
            lines = wrapped(draw, scene['text'], font, right - 64)
            line_height = round(size * 1.5)
            if len(lines) * line_height <= HEIGHT - top - 64:
                break
        else:
            raise ValueError('Scene text does not fit; split it into more scenes.')
        if scene['template'] == 'highlight':
            draw.rounded_rectangle((48, top - 8, right + 12, min(HEIGHT - 40, top + len(lines) * line_height + 8)),
                                   radius=12, fill='#fef3c7')
        for line in lines:
            draw.text((64, top), line, font=font, fill='#1e3a5f')
            top += line_height
    image.save(destination, format='PNG')


def srt_time(seconds):
    milliseconds = round(seconds * 1000)
    hours, remaining = divmod(milliseconds, 3_600_000)
    minutes, remaining = divmod(remaining, 60_000)
    sec, millis = divmod(remaining, 1000)
    return '%02d:%02d:%02d,%03d' % (hours, minutes, sec, millis)


def caption_cues(text, start, duration):
    # Approximate cues from the final spoken script, explicitly not forced alignment.
    words = text.split()
    groups = [' '.join(words[i:i + 12]) for i in range(0, len(words), 12)]
    total = sum(len(x) for x in groups)
    offset, cues = start, []
    for group in groups:
        length = duration * len(group) / total
        cues.append((offset, offset + length, group))
        offset += length
    return cues


def reviewed_cues(scene, duration):
    """Scene-relative reviewed cues; reject stale/invalid timing rather than clip it."""
    if scene.get('captionsNarration') != scene['narration']:
        raise ValueError('Reviewed captions are stale: review them after changing narration.')
    rows = scene.get('captions')
    if not isinstance(rows, list) or not 1 <= len(rows) <= 200:
        raise ValueError('Reviewed captions require 1–200 cues per scene.')
    cues, previous, ids = [], 0.0, set()
    for row in rows:
        if not isinstance(row, dict):
            raise ValueError('Invalid reviewed caption.')
        identifier = row.get('id')
        if not isinstance(identifier, str) or not re.fullmatch(r'[A-Za-z0-9_-]{1,80}', identifier) or identifier in ids:
            raise ValueError('Caption IDs must be unique safe identifiers.')
        ids.add(identifier)
        start, end = row.get('start'), row.get('end')
        if any(isinstance(x, bool) or not isinstance(x, (int, float)) or not math.isfinite(x) for x in (start, end)):
            raise ValueError('Caption times must be finite seconds.')
        if start < previous or end <= start or end > duration + .001:
            raise ValueError('Caption timing overlaps or exceeds actual scene audio; review timings.')
        text = row.get('text')
        if not isinstance(text, str) or not text.strip() or len(text) > 1000:
            raise ValueError('Caption text must have 1–1000 characters.')
        text = re.sub(r'\s+', ' ', text).strip()
        if scene.get('captionMode') == 'bilingual':
            secondary = row.get('secondaryText')
            if not isinstance(secondary, str) or not secondary.strip() or len(secondary) > 1000:
                raise ValueError('Bilingual captions require a reviewed secondary text for every cue.')
            text += '\n' + re.sub(r'\s+', ' ', secondary).strip()
        cues.append((start, end, text))
        previous = end
    return cues


def encode_scene(image, audio, video, duration):
    frames = math.ceil(duration * FPS)
    duration = frames / FPS
    # Slow zoom and a real fade: animation is deterministic and editable by template.
    video_filter = ("scale=1280:720,zoompan=z='min(zoom+0.00006,1.025)':"
                    "x='iw/2-iw/zoom/2':y='ih/2-ih/zoom/2':d=1:s=1280x720:fps=25,"
                    "fade=t=in:st=0:d=0.2,fade=t=out:st=%.3f:d=0.2,format=yuv420p" % max(.2, duration - .2))
    run_ffmpeg(['-loop', '1', '-framerate', FPS, '-i', image, '-i', audio,
                '-vf', video_filter, '-af', 'apad', '-t', '%.3f' % duration,
                '-c:v', 'libx264', '-preset', 'veryfast', '-crf', '23', '-r', FPS,
                # Keep PCM between scenes: per-scene AAC priming/padding otherwise
                # accumulates into audible gaps and caption drift after concat.
                '-c:a', 'pcm_s16le', '-ar', '24000', '-ac', 1,
                '-threads', 2, video])
    return duration


def render(job):
    from preparation_worker import validate_scenes
    from preparation_cache import LessonCache, cache_key, digest_file
    import soundfile as sf
    cache = LessonCache(job)
    scenes = validate_scenes(job.request.get('scenes'))
    translated_indices = [i for i, scene in enumerate(scenes) if scene['language'] == 'vi' and not scene.get('audioPath')]
    if translated_indices:
        translated = job.translate_texts([scenes[i]['narration'] for i in translated_indices], .03, .17)
        for index, text in zip(translated_indices, translated):
            scenes[index]['narration'] = text
            scenes[index]['language'] = 'en'
    audio_paths = [job.path('scene-%03d.wav' % index) for index in range(len(scenes))]
    missing = []
    for index, scene in enumerate(scenes):
        if scene.get('audioPath'):
            # Re-encode even a pre-existing WAV to one bounded known format.
            run_ffmpeg(['-i', scene['audioPath'], '-vn', '-ac', 1, '-ar', 24000, '-t', 900.04,
                        '-c:a', 'pcm_s16le', audio_paths[index]])
        else:
            missing.append(index)
    if missing:
        job.synthesize([scenes[i]['narration'] for i in missing], [audio_paths[i] for i in missing], .22, .3)
    duration_total, videos, cues, timeline = 0, [], [], []
    for index, (scene, audio) in enumerate(zip(scenes, audio_paths)):
        info = sf.info(audio)
        duration = info.frames / info.samplerate
        if not .2 <= duration <= 900:
            raise ValueError('Scene audio must be between 0.2 seconds and 15 minutes; split narration.')
        if duration_total + duration > 1800:
            raise ValueError('Rendered lesson exceeds the current 30-minute limit.')
        image = job.path('scene-%03d.png' % index)
        video = job.path('scene-%03d.mkv' % index)
        visual = {key: scene.get(key) for key in ('title', 'text', 'template')}
        visual['imageHash'] = digest_file(scene['imagePath']) if scene.get('imagePath') else None
        visual['fontHash'] = digest_file(FONT)
        visual['rendererHash'] = digest_file(Path(__file__))
        key = cache_key({'visual': visual, 'audioHash': digest_file(audio), 'duration': duration,
                         'fps': FPS, 'width': WIDTH, 'height': HEIGHT})
        if cache.restore(key, '.png', image) and cache.restore(key, '.mkv', video):
            output_duration = math.ceil(duration * FPS) / FPS
        else:
            draw_scene(scene, image)
            output_duration = encode_scene(image, audio, video, duration)
            cache.save(key, '.png', image)
            cache.save(key, '.mkv', video)
        if scene.get('captionMode') == 'bilingual' and scene.get('captionsReviewed') is not True:
            raise ValueError('Review bilingual captions before rendering.')
        scene_cues = reviewed_cues(scene, duration) if scene.get('captionsReviewed') is True else caption_cues(scene['narration'], 0, duration)
        visible_cues = scene_cues if scene.get('captionsVisible', True) else []
        cues.extend((duration_total + start, duration_total + end, text) for start, end, text in visible_cues)
        scene['audioDuration'] = duration
        if scene.get('captionsReviewed') is not True:
            scene['captions'] = [{'id': 'cue-%d' % (i + 1), 'start': start, 'end': end, 'text': text}
                                 for i, (start, end, text) in enumerate(scene_cues)]
        scene['captionsNarration'] = scene['narration']
        timeline.append({'id': scene['id'], 'start': duration_total, 'duration': output_duration,
                         'spokenDuration': duration, 'language': scene['language']})
        duration_total += output_duration
        videos.append(video)
        job.progress('rendering-scenes', .55 + .35 * (index + 1) / len(scenes))
    concat = job.path('concat.txt')
    # Only worker-generated filenames appear in the concat grammar.
    concat.write_text('\n'.join("file '%s'" % path.name for path in videos), encoding='utf-8')
    final = job.path('lesson.mp4')
    job.progress('assembling-video', .93)
    run_ffmpeg(['-f', 'concat', '-safe', '1', '-i', concat, '-c:v', 'copy',
                '-c:a', 'aac', '-b:a', '128k', '-ar', '24000', '-ac', 1,
                '-movflags', '+faststart', final])
    captions = job.path('lesson.srt')
    captions.write_text('\n\n'.join('%d\n%s --> %s\n%s' % (i + 1, srt_time(start), srt_time(end), text)
                                   for i, (start, end, text) in enumerate(cues)) + '\n', encoding='utf-8')
    thumbnail = job.path('thumbnail.png')
    shutil.copyfile(job.path('scene-000.png'), thumbnail)
    timeline_path = job.path('timeline.json')
    atomic_json(timeline_path, {'duration': duration_total, 'fps': FPS, 'width': WIDTH, 'height': HEIGHT,
                              'scenes': timeline, 'captionTiming': 'reviewed' if all(s.get('captionsReviewed') is True for s in scenes) else 'estimated cues require teacher review'})
    return {'scenes': scenes, 'duration': duration_total, 'captionTiming': 'reviewed' if all(s.get('captionsReviewed') is True for s in scenes) else 'estimated; review before publication',
            'artifacts': [job.artifact(final, 'video', 'video/mp4'), job.artifact(captions, 'subtitle', 'application/x-subrip'),
                          job.artifact(thumbnail, 'thumbnail', 'image/png'), job.artifact(timeline_path, 'timeline', 'application/json')]}
