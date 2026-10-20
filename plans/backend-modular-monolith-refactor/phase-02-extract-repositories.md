# Phase 02: Repository Layer Extraction (Classroom & Planning)

## Goal
Decouple `ClassroomService` and `PlanningService` from direct disk file I/O by creating clean, dedicated `ClassroomRepository` and `PlanningRepository` interfaces with file-based implementations.

---

## Detailed Tasks

### 1. `ClassroomRepository`
- Interface:
  - `Optional<Classroom> findActive()`
  - `boolean saveActive(Classroom classroom)`
  - `boolean clearActive()`
  - `List<Classroom> findAll()`
  - `boolean saveAll(List<Classroom> classrooms)`
  - `JsonObject findContent(String classroomId)`
  - `boolean saveContent(String classroomId, JsonObject content)`
  - `boolean delete(String classroomId)`
  - `boolean deleteAll(String teacherId)`
- Implementation: `FileClassroomRepository` handles disk file operations (`active_classroom.json`, `classrooms.json`, `classrooms/{id}.json`) with thread-safe file lock.
- Refactor `ClassroomService`: Injects `ClassroomRepository`, removing raw `java.nio.file.Files` operations and focusing 100% on classroom session lifecycle rules.

### 2. `PlanningRepository`
- Interface:
  - `List<Planning> findAll()`
  - `Optional<Planning> findById(String id)`
  - `Planning save(Planning planning)`
  - `boolean deleteById(String id)`
- Implementation: `FilePlanningRepository` handles `plannings.json` read/write.
- Refactor `PlanningService`: Injects `PlanningRepository`.

---

## Verification Commands
```powershell
mvn test -f backend/api/pom.xml -Dtest=ClassroomSessionTest
mvn test -f backend/api/pom.xml
```

