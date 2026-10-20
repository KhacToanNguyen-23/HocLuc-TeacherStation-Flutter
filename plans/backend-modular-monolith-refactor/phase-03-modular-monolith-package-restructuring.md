# Phase 03: Modular Monolith Package Reorganization

## Goal
Structure all backend classes into clean, feature-first modular packages (`vn.teaching.modules.*` and `vn.teaching.core.*`) matching the frontend's architecture.

---

## Detailed Tasks

### 1. Structure Modules
- `vn.teaching.core.config`: `CompanionConfig`, `WebConfig`, `GoogleDesktopEnvironment`, `SecurityTokenInterceptor`, `RequestLoggingFilter`
- `vn.teaching.core.exception`: `GlobalExceptionHandler`
- `vn.teaching.core.service`: `StorageService`
- `vn.teaching.core.controller`: `BootstrapController`, `LessonController`
- `vn.teaching.modules.auth`: `controller/`, `service/`, `dto/`
- `vn.teaching.modules.classroom`: `controller/`, `service/`, `repository/`, `entity/`
- `vn.teaching.modules.planning`: `controller/`, `service/`, `repository/`, `entity/`
- `vn.teaching.modules.exam`: `controller/`, `service/`, `repository/`, `model/`, `config/`, `exception/`
- `vn.teaching.modules.integrations.google`: `controller/`, `service/`, `repository/`, `dto/`, `exception/`
- `vn.teaching.modules.plugin`: `controller/`, `service/`, `dto/`
- `vn.teaching.modules.media`: `controller/`, `service/`

### 2. Update Imports & Test Packages
- Update imports across all production classes.
- Update test classes in `backend/api/src/test/java/` to match or cleanly reference new packages.
- Ensure Spring `@SpringBootApplication` in `vn.teaching.CompanionServer` discovers all beans cleanly without explicit scan base packages.

---

## Verification Commands
```powershell
mvn test-compile -f backend/api/pom.xml
mvn test -f backend/api/pom.xml
```

