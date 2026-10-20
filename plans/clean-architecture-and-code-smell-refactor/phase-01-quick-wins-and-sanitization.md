# Phase 01: Quick Wins & Zero-Risk Sanitization

## Goal
Eliminate low-hanging code smells, formatting obfuscation, and silent exception swallowing across Frontend and Backend with zero logic changes.

---

## Detailed Tasks

### 1. Fix Mojibake String Encoding in Backend
- File: `backend/api/src/main/java/vn/teaching/service/ClassroomService.java`
- Replace corrupted UTF-8 string literals with proper Vietnamese:
  - Line 69: `"Chưa lưu được buổi học vào bộ nhớ."`
  - Line 75: `"Chưa lưu được phòng học đang mở."`

### 2. Format & De-Golf Minified Java Classes
- Files:
  - `backend/api/src/main/java/vn/teaching/exam/PaperService.java`
  - `backend/api/src/main/java/vn/teaching/exam/ExamRepository.java`
  - `backend/api/src/main/java/vn/teaching/exam/ExamAuth.java`
- Format packed multi-statement lines into standard Google Java Style (one statement per line, proper indentation, block braces, readable variable names).
- Preserve exact algorithm logic (combinatorics, backtracking knapsack search, quota checks).

### 3. Replace Silent Empty Catch Blocks with Diagnostic Logging
- Replace `catch (_) {}` and `catch (e) {}` with `FrontendLogger.write('[Context] Action failed: $e')`:
  - `frontend/lib/features/auth/services/google_connection_flow.dart`
  - `frontend/lib/features/classroom_meet/services/audio_translation_service.dart`
  - `frontend/lib/features/classroom_meet/services/meet_automation_service.dart`
  - `frontend/lib/features/plugin_engine/services/plugin_web_server.dart`
  - `frontend/lib/features/studio_board/services/english_analyzer.dart`
- In Spring Boot: Replace `catch (Exception ignored) {}` with `log.warn('[Context] Action failed | cause={}', e.getMessage())`:
  - `backend/api/src/main/java/vn/teaching/service/ClassroomService.java`
  - `backend/api/src/main/java/vn/teaching/service/PlanningService.java`
  - `backend/api/src/main/java/vn/teaching/service/PluginMarketplaceService.java`
  - `backend/api/src/main/java/vn/teaching/integrations/GoogleHttpGateway.java`

---

## Verification Commands
```powershell
mvn test -f backend/api/pom.xml
flutter test test/architecture_test.dart
```

