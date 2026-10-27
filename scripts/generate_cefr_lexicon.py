#!/usr/bin/env python3
"""Generate deterministic CEFR headword maps from attributed source CSVs."""

from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Any


LEVELS = ("A1", "A2", "B1", "B2", "C1", "C2")
LEVEL_RANK = {level: rank for rank, level in enumerate(LEVELS)}
TOKEN_RE = re.compile(r"^[a-z]+(?:[-'][a-z]+)*$")
IRREGULAR_INFLECTIONS = {
    "children": "child",
    "feet": "foot",
    "geese": "goose",
    "men": "man",
    "mice": "mouse",
    "people": "person",
    "teeth": "tooth",
    "women": "woman",
    "went": "go",
    "gone": "go",
    "was": "be",
    "were": "be",
    "been": "be",
    "did": "do",
    "done": "do",
    "had": "have",
    "has": "have",
    "made": "make",
    "took": "take",
    "taken": "take",
    "wrote": "write",
    "written": "write",
}
INVARIANT_PLURALS = {"species", "series", "news", "mathematics", "physics", "politics", "economics"}
GENERATED_SHARD_SIZE = 350


class LexiconError(ValueError):
    """Raised when source metadata or rows are unsuitable for generation."""


def _source_rows(source: dict[str, Any], source_dir: Path) -> list[dict[str, str]]:
    path = source_dir / source["file"]
    if not path.is_file():
        raise LexiconError(f"{source['id']}: source file not found: {path}")
    for field in ("id", "citation", "license", "url"):
        if not str(source.get(field, "")).strip():
            raise LexiconError(f"{source.get('id', path.name)}: missing {field}")

    try:
        with path.open(encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            required = {
                source["headword_column"],
                source["pos_column"],
                source["level_column"],
            }
            missing = required.difference(reader.fieldnames or ())
            if missing:
                raise LexiconError(
                    f"{source['id']}: missing columns {sorted(missing)}"
                )
            return [dict(row) for row in reader]
    except (OSError, UnicodeError, csv.Error) as error:
        raise LexiconError(f"{source['id']}: cannot read {path}: {error}") from error


def _inflection_candidates(word: str) -> list[str]:
    candidates = []
    irregular = IRREGULAR_INFLECTIONS.get(word)
    if irregular:
        candidates.append(irregular)
    if word in INVARIANT_PLURALS:
        return candidates
    if word.endswith("ies") and len(word) > 4:
        candidates.append(word[:-3] + "y")
    if word.endswith("ves") and len(word) > 4:
        candidates.extend((word[:-3] + "f", word[:-3] + "fe"))
    if word.endswith("es") and len(word) > 4:
        candidates.append(word[:-2])
    if word.endswith("s") and not word.endswith("ss") and len(word) > 3:
        candidates.append(word[:-1])
    if word.endswith("ing") and len(word) > 5:
        stem = word[:-3]
        candidates.append(stem)
        if len(stem) > 3 and stem[-1] == stem[-2]:
            candidates.append(stem[:-1])
        candidates.append(stem + "e")
    if word.endswith("ed") and len(word) > 4:
        stem = word[:-2]
        candidates.append(stem)
        if len(stem) > 3 and stem[-1] == stem[-2]:
            candidates.append(stem[:-1])
        candidates.append(stem + "e")
    return list(dict.fromkeys(candidate for candidate in candidates if candidate != word))


def _derivational_candidates(word: str) -> list[str]:
    candidates = []
    if word.endswith("ly") and len(word) > 4:
        stem = word[:-2]
        candidates.append(stem)
        if stem.endswith("i"):
            candidates.append(stem[:-1] + "y")
    if word.endswith("ness") and len(word) > 5:
        stem = word[:-4]
        candidates.append(stem)
        if stem.endswith("i"):
            candidates.append(stem[:-1] + "y")
    # -ation is intentionally excluded: e.g. medication is not medicate.
    return list(dict.fromkeys(candidate for candidate in candidates if candidate != word))


def _recognized_unrated(path: Path | None, known_labeled: set[str]) -> dict[str, str]:
    if path is None:
        return {}
    if not path.is_file():
        raise LexiconError(f"recognized-unrated source file not found: {path}")
    words: dict[str, str] = {}
    with path.open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if not {"headword", "provenance"}.issubset(reader.fieldnames or ()):
            raise LexiconError("recognized-unrated CSV requires headword and provenance columns")
        for row_number, row in enumerate(reader, start=2):
            word = str(row.get("headword", "")).strip().lower()
            provenance = str(row.get("provenance", "")).strip()
            if not TOKEN_RE.fullmatch(word) or not provenance:
                raise LexiconError(f"recognized-unrated:{row_number}: invalid headword or missing provenance")
            if word in known_labeled:
                raise LexiconError(f"recognized-unrated:{row_number}: {word!r} already has a CEFR label")
            if word in words:
                raise LexiconError(f"recognized-unrated:{row_number}: duplicate headword {word!r}")
            words[word] = provenance
    return words


def _awl_counts(config: dict[str, Any], root: Path) -> dict[str, int]:
    headword_path = root / config["headword_source_file"]
    if not headword_path.is_file():
        raise LexiconError(f"AWL headword file not found: {headword_path}")
    text = headword_path.read_text(encoding="utf-8-sig")
    symbol = re.escape(config["headword_symbol"])
    match = re.search(rf"const\s+Map<[^>]+>\s+{symbol}\s*=\s*\{{(.*?)\}};", text, re.DOTALL)
    if not match:
        raise LexiconError(f"AWL headword symbol not found: {config['headword_symbol']}")
    headwords = set(re.findall(r"^\s*'([^']+)'\s*:", match.group(1), re.MULTILINE))
    forms = set()
    for path in sorted(root.glob(config["family_forms_glob"])):
        forms.update(re.findall(r"^\s*'([^']+)'\s*:", path.read_text(encoding="utf-8-sig"), re.MULTILINE))
    return {"awl_headwords": len(headwords), "awl_family_forms": len(forms)}


def _legacy_curated_audit(
    path: Path | None,
    source_entries: dict[str, dict[str, Any]],
) -> dict[str, Any]:
    if path is None:
        return {
            "legacy_curated_word_count": 0,
            "legacy_chunk_override_count": 0,
            "legacy_chunk_overrides": [],
            "source_supported_same_label_count": 0,
            "source_supported_conflict_count": 0,
            "no_source_label_count": 0,
            "same_label": [],
            "conflicts": [],
            "unlabeled": [],
        }
    if not path.is_file():
        raise LexiconError(f"legacy curated source file not found: {path}")
    text = path.read_text(encoding="utf-8-sig")
    assignments: dict[str, str] = {}
    overrides = []
    for level in LEVELS:
        match = re.search(
            rf"static const List<String> _{level.lower()}Chunks\s*=\s*\[(.*?)\n\s*\];",
            text,
            re.DOTALL,
        )
        if not match:
            raise LexiconError(f"legacy curated source missing _{level.lower()}Chunks")
        for chunk in re.findall(r"'([^']*)'", match.group(1)):
            for word in chunk.split():
                previous = assignments.get(word)
                if previous and previous != level:
                    overrides.append(
                        {"headword": word, "overridden_level": previous, "selected_level": level}
                    )
                assignments[word] = level

    same_label = []
    conflicts = []
    unlabeled = []
    for word, legacy_level in sorted(assignments.items()):
        source_entry = source_entries.get(word)
        if source_entry is None:
            unlabeled.append({"headword": word, "legacy_level": legacy_level})
        elif source_entry["level"] == legacy_level:
            same_label.append(
                {
                    "headword": word,
                    "level": legacy_level,
                    "source_rows": source_entry["source_rows"],
                }
            )
        else:
            conflicts.append(
                {
                    "headword": word,
                    "legacy_level": legacy_level,
                    "source_level": source_entry["level"],
                    "source_rows": source_entry["source_rows"],
                }
            )
    return {
        "legacy_curated_word_count": len(assignments),
        "legacy_chunk_override_count": len(overrides),
        "legacy_chunk_overrides": overrides,
        "source_supported_same_label_count": len(same_label),
        "source_supported_conflict_count": len(conflicts),
        "no_source_label_count": len(unlabeled),
        "same_label": same_label,
        "conflicts": conflicts,
        "unlabeled": unlabeled,
    }


def collect_entries(
    manifest: dict[str, Any], source_dir: Path
) -> tuple[dict[str, dict[str, Any]], dict[str, Any]]:
    sources = manifest.get("sources")
    if not isinstance(sources, list) or not sources:
        raise LexiconError("manifest must define at least one source")

    records: dict[str, list[dict[str, Any]]] = defaultdict(list)
    normalized_spelling_rows: dict[str, list[dict[str, Any]]] = defaultdict(list)
    source_counts: dict[str, dict[str, int]] = {}
    source_ids: set[str] = set()

    for source in sources:
        source_id = source.get("id", "")
        if not source_id or source_id in source_ids:
            raise LexiconError(f"source id is missing or duplicated: {source_id!r}")
        source_ids.add(source_id)
        source_counts[source_id] = {
            "rows": 0,
            "tokens": 0,
            "skipped_multiword": 0,
            "skipped_invalid": 0,
            "missing_pos_rows": 0,
        }
        rows = _source_rows(source, source_dir)
        fields = (
            source["headword_column"],
            source["pos_column"],
            source["level_column"],
        )
        for row_number, row in enumerate(rows, start=2):
            raw_headword, pos, level = (str(row.get(field, "")).strip() for field in fields)
            if not raw_headword or level.upper() not in LEVEL_RANK:
                raise LexiconError(
                    f"{source_id}:{row_number}: missing headword or invalid CEFR {level!r}"
                )
            if not pos:
                pos = "unspecified"
                source_counts[source_id]["missing_pos_rows"] += 1
            source_counts[source_id]["rows"] += 1
            # Slash-separated spellings in these profiles are equivalent forms.
            for raw_spelling in raw_headword.split("/"):
                raw_spelling = raw_spelling.strip()
                spelling = raw_spelling.lower()
                if not spelling:
                    continue
                if any(char.isspace() for char in spelling):
                    source_counts[source_id]["skipped_multiword"] += 1
                    continue
                if not TOKEN_RE.fullmatch(spelling):
                    source_counts[source_id]["skipped_invalid"] += 1
                    continue
                source_counts[source_id]["tokens"] += 1
                normalized_spelling_rows[spelling].append(
                    {
                        "raw_spelling": raw_spelling,
                        "source": source_id,
                        "row": row_number,
                    }
                )
                records[spelling].append(
                    {
                        "level": level.upper(),
                        "pos": pos.lower(),
                        "source": source_id,
                        "row": row_number,
                    }
                )

    projected: dict[str, dict[str, Any]] = {}
    conflicts: list[dict[str, Any]] = []
    source_normalization_collisions = []
    for normalized, raw_rows in sorted(normalized_spelling_rows.items()):
        raw_spellings = {row["raw_spelling"] for row in raw_rows}
        if len(raw_spellings) > 1:
            source_normalization_collisions.append(
                {
                    "normalized_headword": normalized,
                    "source_spellings": sorted(raw_spellings),
                    "source_rows": raw_rows,
                }
            )
    for word in sorted(records):
        entries = records[word]
        levels = sorted({entry["level"] for entry in entries}, key=LEVEL_RANK.get)
        selected = levels[0]
        pos_levels: dict[str, list[str]] = {}
        for entry in entries:
            pos_levels.setdefault(entry["pos"], [])
            if entry["level"] not in pos_levels[entry["pos"]]:
                pos_levels[entry["pos"]].append(entry["level"])
        for values in pos_levels.values():
            values.sort(key=LEVEL_RANK.get)
        projected[word] = {
            "level": selected,
            "levels": levels,
            "pos_levels": dict(sorted(pos_levels.items())),
            "sources": sorted({entry["source"] for entry in entries}),
            "source_rows": [
                {
                    "source": entry["source"],
                    "row": entry["row"],
                    "pos": entry["pos"],
                    "level": entry["level"],
                }
                for entry in entries
            ],
        }
        if len(levels) > 1:
            conflicts.append(
                {
                    "headword": word,
                    "levels": levels,
                    "selected_word_level": selected,
                    "pos_levels": dict(sorted(pos_levels.items())),
                    "source_rows": [
                        {
                            "source": entry["source"],
                            "row": entry["row"],
                            "pos": entry["pos"],
                            "level": entry["level"],
                        }
                        for entry in entries
                    ],
                }
            )

    recognized_file = manifest.get("recognized_unrated_file")
    unrated = _recognized_unrated(
        source_dir / recognized_file if recognized_file else None,
        set(projected),
    )
    legacy_path = manifest.get("legacy_curated_chunks_file")
    legacy_audit = _legacy_curated_audit(
        (source_dir.parent.parent / legacy_path) if legacy_path else None,
        projected,
    )
    for item in legacy_audit["unlabeled"]:
        unrated.setdefault(
            item["headword"],
            "Legacy HocLuc curated word; no source-backed CEFR label, retained as recognized-unrated.",
        )

    inflected_forms: dict[str, list[str]] = {}
    ambiguous_normalizations: list[dict[str, Any]] = []
    for word in sorted(projected):
        candidates = [
            candidate
            for candidate in _inflection_candidates(word)
            if candidate in projected
        ]
        candidates = list(dict.fromkeys(candidates))
        if candidates:
            inflected_forms[word] = candidates
        if len(candidates) > 1:
            ambiguous_normalizations.append({"form": word, "candidates": candidates})

    awl = _awl_counts(manifest["awl_counts"], source_dir.parent.parent) if manifest.get("awl_counts") else {
        "awl_headwords": 0,
        "awl_family_forms": 0,
    }
    awl_path = manifest.get("awl_counts")
    awl_headwords: set[str] = set()
    if awl_path:
        headword_text = (source_dir.parent.parent / awl_path["headword_source_file"]).read_text(encoding="utf-8-sig")
        symbol_match = re.search(
            rf"const\s+Map<[^>]+>\s+{re.escape(awl_path['headword_symbol'])}\s*=\s*\{{(.*?)\}};",
            headword_text,
            re.DOTALL,
        )
        if symbol_match:
            awl_headwords = set(re.findall(r"^\s*'([^']+)'\s*:", symbol_match.group(1), re.MULTILINE))
    awl_only = awl_headwords - set(projected)
    cefr_headwords = set(projected) - set(inflected_forms)

    report = {
        "source_counts": source_counts,
        "unique_cefr_headwords": len(projected),
        "cefr_labeled_headwords_excluding_inflections": len(cefr_headwords),
        "cefr_labeled_inflected_or_derived_forms": len(inflected_forms),
        "recognized_unrated_headwords": len(unrated),
        "recognized_unrated_entries": unrated,
        "legacy_curated_audit": legacy_audit,
        "awl_headwords": awl["awl_headwords"],
        "awl_family_forms": awl["awl_family_forms"],
        "awl_only_headwords": len(awl_only),
        "source_normalization_collision_count": len(source_normalization_collisions),
        "source_normalization_collisions": source_normalization_collisions,
        "ambiguous_inflection_normalization_count": len(ambiguous_normalizations),
        "ambiguous_inflection_normalizations": ambiguous_normalizations,
        "level_counts": {
            level: sum(entry["level"] == level for entry in projected.values())
            for level in LEVELS
        },
        "pos_level_conflict_count": len(conflicts),
        "pos_level_conflicts": conflicts,
    }
    return projected, report


def render_dart(
    entries: dict[str, dict[str, Any]],
    manifest: dict[str, Any],
    recognized_unrated: dict[str, str] | None = None,
) -> str:
    shard_count = (len(entries) + GENERATED_SHARD_SIZE - 1) // GENERATED_SHARD_SIZE
    lines = [
        "// GENERATED FILE. Run scripts/generate_cefr_lexicon.py to update.",
        "// CEFR-J word-level projection: earliest CEFR label present in source POS rows.",
    ]
    for source in manifest["sources"]:
        lines.append(f"// {source['id']}: {source['citation']}")
        lines.append(f"// License: {source['license']}")
        lines.append(f"// Source: {source['url']}")
    for shard_index in range(1, shard_count + 1):
        lines.append(
            f"import 'generated_cefr_source_words_part_{shard_index:02d}.dart';"
        )
    lines.extend(["", "const Map<String, String> generatedCefrSourceWords = {"])
    lines.extend(
        f"  ...generatedCefrSourceWordsPart{index:02d},"
        for index in range(1, shard_count + 1)
    )
    lines.extend(["};", "", "const Set<String> generatedCefrSourceHeadwords = {"])
    lines.extend(
        f"  ...generatedCefrSourceHeadwordsPart{index:02d},"
        for index in range(1, shard_count + 1)
    )
    lines.extend(["};", ""])
    # Keep explicit inflection and headword sets available to downstream phases.
    # Derivations such as bitterness remain independent headwords.
    inflected = {
        word: [candidate for candidate in _inflection_candidates(word) if candidate in entries]
        for word in entries
    }
    inflected = {word: list(dict.fromkeys(bases)) for word, bases in inflected.items() if bases}
    lines.extend(["const Map<String, List<String>> generatedCefrSourceInflections = {"])
    lines.extend(
        f"  {json.dumps(word)}: {json.dumps(bases)}," for word, bases in sorted(inflected.items())
    )
    lines.extend(["};", ""])
    recognized = recognized_unrated or {}
    lines.extend(["const Set<String> generatedRecognizedUnratedWords = {"])
    lines.extend(f"  {json.dumps(word)}," for word in sorted(recognized))
    lines.extend(["};", ""])
    return "\n".join(lines)


def render_dart_shards(entries: dict[str, dict[str, Any]]) -> dict[str, str]:
    """Split the large immutable lexicon into source files below architecture limits."""
    inflected = {
        word: [candidate for candidate in _inflection_candidates(word) if candidate in entries]
        for word in entries
    }
    inflected = {word for word, bases in inflected.items() if bases}
    words = sorted(entries)
    shards = {}
    for offset in range(0, len(words), GENERATED_SHARD_SIZE):
        index = offset // GENERATED_SHARD_SIZE + 1
        chunk = words[offset : offset + GENERATED_SHARD_SIZE]
        lines = [
            "// GENERATED FILE. Run scripts/generate_cefr_lexicon.py to update.",
            f"const Map<String, String> generatedCefrSourceWordsPart{index:02d} = {{",
        ]
        lines.extend(
            f"  {json.dumps(word)}: {json.dumps(entries[word]['level'])}," for word in chunk
        )
        lines.extend(["};", "", f"const Set<String> generatedCefrSourceHeadwordsPart{index:02d} = {{"])
        lines.extend(f"  {json.dumps(word)}," for word in chunk if word not in inflected)
        lines.extend(["};", ""])
        shards[f"part_{index:02d}"] = "\n".join(lines)
    return shards


def main(argv: list[str] | None = None, *, root_override: Path | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=Path("data/vocabulary_sources/manifest.json"),
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(
            "frontend/lib/features/studio_board/services/profiler/"
            "generated_cefr_source_words.dart"
        ),
    )
    parser.add_argument(
        "--report",
        type=Path,
        default=Path("data/vocabulary_sources/validation_report.json"),
    )
    parser.add_argument("--min-headwords", type=int)
    parser.add_argument("--max-headwords", type=int)
    parser.add_argument("--check", action="store_true", help="Fail if outputs are stale")
    parser.add_argument("--dry-run", action="store_true", help="Validate without writing")
    args = parser.parse_args(argv)

    root = root_override.resolve() if root_override else Path(__file__).resolve().parents[1]
    manifest_path = (root / args.manifest).resolve()
    output_path = (root / args.output).resolve()
    report_path = (root / args.report).resolve()
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        source_dir = manifest_path.parent
        entries, report = collect_entries(manifest, source_dir)
        target = manifest.get("headword_target", {})
        minimum = args.min_headwords if args.min_headwords is not None else target.get("minimum")
        maximum = args.max_headwords if args.max_headwords is not None else target.get("maximum")
        count = report["cefr_labeled_headwords_excluding_inflections"]
        if minimum is not None and count < minimum:
            raise LexiconError(f"unique CEFR headwords {count} is below minimum {minimum}")
        if maximum is not None and count > maximum:
            raise LexiconError(f"unique CEFR headwords {count} exceeds maximum {maximum}")
        recognized_path = (
            source_dir / manifest["recognized_unrated_file"]
            if manifest.get("recognized_unrated_file")
            else None
        )
        recognized = report["recognized_unrated_entries"]
        rendered = render_dart(entries, manifest, recognized)
        rendered_shards = render_dart_shards(entries)
        report_text = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
        if args.check:
            if not output_path.is_file() or output_path.read_text(encoding="utf-8") != rendered:
                raise LexiconError(f"generated Dart file is stale: {output_path}")
            shard_dir = output_path.parent
            shard_prefix = f"{output_path.stem}_part_"
            existing_shards = {
                path.name: path
                for path in shard_dir.glob(f"{shard_prefix}*.dart")
            }
            expected_shards = {
                f"{output_path.stem}_{name}.dart": content
                for name, content in rendered_shards.items()
            }
            for shard_name, shard_text in expected_shards.items():
                shard_path = shard_dir / shard_name
                if not shard_path.is_file() or shard_path.read_text(encoding="utf-8") != shard_text:
                    raise LexiconError(f"generated Dart shard is stale: {shard_path}")
            stale_shards = set(existing_shards) - set(expected_shards)
            if stale_shards:
                raise LexiconError(
                    f"stale generated Dart shards: {', '.join(sorted(stale_shards))}"
                )
            if not report_path.is_file() or report_path.read_text(encoding="utf-8") != report_text:
                raise LexiconError(f"validation report is stale: {report_path}")
        elif not args.dry_run:
            output_path.parent.mkdir(parents=True, exist_ok=True)
            report_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_text(rendered, encoding="utf-8", newline="\n")
            for name, content in rendered_shards.items():
                shard_path = output_path.with_name(f"{output_path.stem}_{name}.dart")
                shard_path.write_text(content, encoding="utf-8", newline="\n")
            shard_prefix = f"{output_path.stem}_part_"
            expected_shard_names = {
                f"{output_path.stem}_{name}.dart" for name in rendered_shards
            }
            for stale_path in output_path.parent.glob(f"{shard_prefix}*.dart"):
                if stale_path.name not in expected_shard_names:
                    stale_path.unlink()
            report_path.write_text(report_text, encoding="utf-8", newline="\n")
    except (OSError, json.JSONDecodeError, KeyError, LexiconError) as error:
        print(f"[CEFR lexicon] ERROR: {error}", file=sys.stderr)
        return 1

    print(
        "[CEFR lexicon] "
        f"{report['cefr_labeled_headwords_excluding_inflections']} CEFR headwords, "
        f"{report['cefr_labeled_inflected_or_derived_forms']} labeled forms; "
        f"{report['pos_level_conflict_count']} POS/level collisions reported"
        + (" (check passed)" if args.check else " (dry run)" if args.dry_run else " (generated)")
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
