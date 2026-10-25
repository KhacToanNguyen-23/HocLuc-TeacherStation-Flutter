# Phase 04: Pedagogical Recommendations & VSTEP Exam Profile

## Objective
Translate calculated linguistic metrics into actionable teacher suggestions and provide an exam preparation profile comparing the text against VSTEP (B1, B2, C1) and THPT/ĐGNL benchmarks.

## Scope
- Implement `TeacherRecommendationEngine` in `frontend/lib/features/studio_board/services/profiler/teacher_recommendation_engine.dart`:
  - Rule-based, deterministic suggestions linked directly to metrics:
    - Pre-teaching vocabulary when B2+ or unfamiliar words exceed 10%.
    - Sentence breakdown advice when sentences > 25 words or multiple subordinate clauses exist.
    - Grammar focus tips when passive voice or inversion/participles are detected.
    - Readability alignment with target student grade level (Lower secondary vs Upper secondary vs University prep).
- Implement `ExamProfiler` in `frontend/lib/features/studio_board/services/profiler/exam_profiler.dart`:
  - VSTEP Profile:
    - VSTEP B1 (Flesch Ease 65-80, B1 vocabulary >= 75%, avg sentence 12-16 words).
    - VSTEP B2 (Flesch Ease 50-65, B2 vocabulary 15-25%, avg sentence 16-22 words).
    - VSTEP C1 (Flesch Ease 30-50, C1 vocabulary >= 10%, academic vocabulary >= 8%, avg sentence > 22 words).
  - THPT / ĐGNL Profile:
    - Distinguishes basic reading comprehension vs high-differentiation passages (câu phân loại 9-10).
  - Explicit disclaimers: Pedagogical benchmark reference, not an official test guarantee.

## Affected Files
- `frontend/lib/features/studio_board/services/profiler/teacher_recommendation_engine.dart`
- `frontend/lib/features/studio_board/services/profiler/exam_profiler.dart`

## Tests / Acceptance Criteria
- Recommendations correctly flag long sentences and provide concrete pre-teach lists.
- Exam profile evaluates test difficulty on VSTEP and ĐGNL scales with realistic fit indicators.

