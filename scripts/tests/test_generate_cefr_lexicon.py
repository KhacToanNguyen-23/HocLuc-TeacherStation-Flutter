import csv
import json
import tempfile
import unittest
from pathlib import Path
from scripts.generate_cefr_lexicon import LexiconError, collect_entries, main, render_dart


class GenerateCefrLexiconTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.source_dir = self.root / "sources"
        self.source_dir.mkdir()
        self.source_path = self.source_dir / "fixture.csv"
        self._write_rows(
            [
                ("noodle", "noun", "A2"),
                ("colour/color", "noun", "A1"),
                ("color", "verb", "B2"),
                ("ice cream", "noun", "A1"),
                ("species", "noun", "B1"),
                ("medication", "noun", "B2"),
                ("medications", "noun", "B2"),
                ("bitter", "adjective", "B1"),
                ("bitterness", "noun", "B2"),
            ]
        )
        self.manifest = {
            "schema_version": 1,
            "headword_target": {"minimum": 1, "maximum": 10},
            "sources": [
                {
                    "id": "fixture-source",
                    "file": "fixture.csv",
                    "headword_column": "headword",
                    "pos_column": "pos",
                    "level_column": "CEFR",
                    "citation": "Fixture source for generator tests",
                    "license": "CC0-1.0",
                    "url": "https://example.invalid/fixture",
                }
            ],
        }

    def tearDown(self):
        self.temp.cleanup()

    def _write_rows(self, rows):
        with self.source_path.open("w", encoding="utf-8", newline="") as handle:
            writer = csv.writer(handle)
            writer.writerow(["headword", "pos", "CEFR"])
            writer.writerows(rows)

    def test_normalizes_variants_and_reports_pos_level_collisions(self):
        entries, report = collect_entries(self.manifest, self.source_dir)

        self.assertEqual(entries["noodle"]["level"], "A2")
        self.assertEqual(entries["colour"]["level"], "A1")
        self.assertEqual(entries["color"]["level"], "A1")
        self.assertEqual(entries["color"]["pos_levels"], {"noun": ["A1"], "verb": ["B2"]})
        self.assertNotIn("ice cream", entries)
        self.assertEqual(report["unique_cefr_headwords"], 8)
        self.assertEqual(report["cefr_labeled_headwords_excluding_inflections"], 7)
        self.assertEqual(report["cefr_labeled_inflected_or_derived_forms"], 1)
        self.assertEqual(report["pos_level_conflict_count"], 1)
        self.assertEqual(report["source_counts"]["fixture-source"]["skipped_multiword"], 1)

    def test_recognized_unrated_entries_are_kept_out_of_labeled_counts(self):
        (self.source_dir / "recognized.csv").write_text(
            "headword,provenance\nsnack,reviewed lexical item\n", encoding="utf-8"
        )
        manifest = json.loads(json.dumps(self.manifest))
        manifest["recognized_unrated_file"] = "recognized.csv"
        entries, report = collect_entries(manifest, self.source_dir)

        self.assertEqual(report["recognized_unrated_entries"], {"snack": "reviewed lexical item"})
        self.assertNotIn("snack", entries)

    def test_rejects_recognized_unrated_entry_with_existing_cefr_label(self):
        (self.source_dir / "recognized.csv").write_text(
            "headword,provenance\nnoodle,reviewed lexical item\n", encoding="utf-8"
        )
        manifest = json.loads(json.dumps(self.manifest))
        manifest["recognized_unrated_file"] = "recognized.csv"
        with self.assertRaisesRegex(LexiconError, "already has a CEFR label"):
            collect_entries(manifest, self.source_dir)

    def test_generated_dart_is_deterministic_and_auditable(self):
        first, report = collect_entries(self.manifest, self.source_dir)
        second, _ = collect_entries(self.manifest, self.source_dir)

        self.assertEqual(render_dart(first, self.manifest), render_dart(second, self.manifest))
        self.assertIn("fixture-source", render_dart(first, self.manifest))
        self.assertEqual(report["pos_level_conflicts"][0]["headword"], "color")

    def test_rejects_invalid_levels(self):
        self._write_rows([("word", "noun", "C3")])
        with self.assertRaisesRegex(LexiconError, "invalid CEFR"):
            collect_entries(self.manifest, self.source_dir)

    def test_reports_normalized_source_collisions_with_equal_labels(self):
        self._write_rows([("color", "noun", "A1"), ("COLOR", "noun", "A1")])

        _, report = collect_entries(self.manifest, self.source_dir)

        self.assertEqual(report["source_normalization_collision_count"], 1)
        collision = report["source_normalization_collisions"][0]
        self.assertEqual(collision["normalized_headword"], "color")
        self.assertEqual(collision["source_spellings"], ["COLOR", "color"])
        self.assertEqual({row["row"] for row in collision["source_rows"]}, {2, 3})
        self.assertEqual({row["source"] for row in collision["source_rows"]}, {"fixture-source"})

    def test_audits_legacy_levels_and_moves_unlabeled_words_to_recognized(self):
        legacy_path = self.root / "legacy.dart"
        chunks = {
            "a1": "noodle",
            "a2": "",
            "b1": "",
            "b2": "medication",
            "c1": "",
            "c2": "ungradedlegacy",
        }
        legacy_text = "\n".join(
            f"static const List<String> _{level}Chunks = [\n'{chunk}',\n];"
            for level, chunk in chunks.items()
        )
        legacy_path.write_text(legacy_text, encoding="utf-8")
        manifest = json.loads(json.dumps(self.manifest))
        manifest["legacy_curated_chunks_file"] = str(legacy_path)

        _, report = collect_entries(manifest, self.source_dir)

        audit = report["legacy_curated_audit"]
        self.assertEqual(audit["legacy_curated_word_count"], 3)
        self.assertEqual(audit["source_supported_conflict_count"], 1)
        self.assertEqual(audit["source_supported_same_label_count"], 1)
        self.assertEqual(audit["no_source_label_count"], 1)
        self.assertEqual(audit["same_label"][0]["source_rows"][0]["source"], "fixture-source")
        self.assertIn("ungradedlegacy", report["recognized_unrated_entries"])

    def test_rejects_missing_provenance(self):
        manifest = json.loads(json.dumps(self.manifest))
        manifest["sources"][0]["license"] = ""
        with self.assertRaisesRegex(LexiconError, "missing license"):
            collect_entries(manifest, self.source_dir)

    def test_cli_dry_run_does_not_write_generated_files(self):
        manifest_path = self.source_dir / "manifest.json"
        manifest_path.write_text(json.dumps(self.manifest), encoding="utf-8")
        output = self.root / "generated.dart"
        report = self.root / "report.json"

        result = main(
            [
                "--manifest",
                "sources/manifest.json",
                "--output",
                "generated.dart",
                "--report",
                "report.json",
                "--dry-run",
            ],
            root_override=self.root,
        )

        self.assertEqual(result, 0)
        self.assertFalse(output.exists())
        self.assertFalse(report.exists())


if __name__ == "__main__":
    unittest.main()
