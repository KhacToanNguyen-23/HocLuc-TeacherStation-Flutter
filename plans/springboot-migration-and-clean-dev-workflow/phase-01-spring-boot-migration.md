# Phase 1: Nâng cấp Backend lên Spring Boot 3

## Requirements
- Update `backend/service/pom.xml` with Spring Boot 3.2.5 starter parent and `spring-boot-starter-web`.
- Add `application.properties` with port 47831.
- Refactor `CompanionServer.java` to `@SpringBootApplication` and CORS configuration.
- Convert `ClassroomController`, `LessonController`, `DeviceController` to `@RestController`.
- Ensure `/api/bootstrap` is mapped.
- Compile and verify with `mvn clean compile`.
