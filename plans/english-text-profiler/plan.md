# Plan: English Text Profiler for Học Lực Teacher Station

Mode: --auto
Risk: normal — Extends text analysis with deterministic metrics and pedagogical profiler without breaking existing scanner/PDF workflows.

## Overview
Transform the existing passage scanning tool into a comprehensive, 100% offline-first **English Text Profiler** for teachers creating lesson materials, reading exercises, and exams (including VSTEP & ĐGNL/THPT).

## Core Architecture
1. **Domain Models (`TextProfileResult` & Sub-models)**:
   - Input statistics (words, characters, sentences, syllables, polysyllables).
   - CEFR Lexical distribution (A1–C2 counts, percentages, proper nouns, numbers, unknown words).
   - Readability metrics (6 standard metrics with formulas, interpretations, limitations).
   - Lexical diversity (TTR, MATTR, MTLD, frequency & academic vocabulary).
   - Syntactic complexity (sentence lengths, clause structures, passives, complex patterns).
   - Vocabulary coverage (K1–K3+ bands, off-list items, pre-teach suggestions).
   - Pedagogical recommendations (traceable, deterministic rules).
   - Exam profile (VSTEP B1/B2/C1 & ĐGNL comparison).

2. **Deterministic Profiling Engine**:
   - `TextProfilerService` in Dart (runs fully offline in the Flutter client without backend dependency).
   - Enhanced Python sidecar (`text_profiler.py` / `dgnl_analyzer.py`) for parity when sidecar is active.
   - Built-in documented CEFR lexical dataset (2,500+ curated headwords with POS awareness and frequency bands).

3. **Teacher-Centric UI & Workflow**:
   - Accessible via PDF Passage Toolbar ("Hồ sơ ngữ liệu" / "Text Profiler" button) and plugin panel.
   - Liquid glass styled dashboard modal with tabs: Overview, CEFR Vocabulary, Readability, Lexical Diversity, Syntactic Complexity, Coverage & Pre-teach, Recommendations, Exam Profile.
   - Expanded 6-level CEFR color-coded highlight filters directly in PDF overlay (A1: #22c55e, A2: #14b8a6, B1: #3b82f6, B2: #f59e0b, C1: #f97316, C2: #a855f7, Unknown: #94a3b8).
   - Word inspection sheet on click (lemma, level, POS, role, context).

4. **Testing & Invariant CI Gates**:
   - Comprehensive unit tests validating mathematical calculations against published reference baselines.
   - Architecture test pass (12/12 invariants).
   - Plugin sync validation (`scripts/validate_plugins.mjs`).

## Phases
- `phase-01-profiling-data-models-and-deterministic-engine`: Core data models and syllable/sentence tokenization engine.
- `phase-02-cefr-vocabulary-profiler-and-coverage`: 6 CEFR level classifier, K1-K3+ frequency coverage, and pre-teach vocabulary extraction.
- `phase-03-readability-lexical-diversity-syntactic-complexity`: 6 Readability formulas, TTR/MATTR/MTLD lexical diversity, and syntactic pattern detection.
- `phase-04-pedagogical-recommendations-and-vstep-profile`: Rule-based teaching suggestions and VSTEP/ĐGNL exam benchmark alignment.
- `phase-05-frontend-text-profiler-dashboard-and-pdf-overlay`: Flutter UI modal dashboard, 6-level CEFR PDF overlay filtering, and word click inspection.
- `phase-06-python-sidecar-sync-and-testing-ci-gate`: Python sidecar endpoint sync, plugin packaging (`.hlep`), comprehensive unit tests, and CI gate checks.

