package vn.teaching.integrations;

import org.springframework.stereotype.Service;
import java.time.Instant;
import java.util.*;
import static vn.teaching.integrations.GoogleConnectionService.*;

/**
 * Handles Google Calendar scheduling, attendee synchronization,
 * Hangouts Meet room generation, and session readiness checks.
 */
@Service
public class GoogleScheduleService {
    private static final String CALENDAR = "https://www.googleapis.com/calendar/v3/calendars/primary/events";

    private final GoogleConnectionService connections;
    private final GoogleGateway google;
    private final GoogleStore store;
    private final vn.teaching.service.ClassroomService classrooms;

    public GoogleScheduleService(GoogleConnectionService connections,
                                 GoogleGateway google,
                                 GoogleStore store,
                                 vn.teaching.service.ClassroomService classrooms) {
        this.connections = connections;
        this.google = google;
        this.store = store;
        this.classrooms = classrooms;
    }

    public synchronized Map<String, Object> schedule(String email, String id, String requestId, String start, String end) {
        requireId(requestId);
        Instant from, to;
        try {
            from = Instant.parse(start).truncatedTo(java.time.temporal.ChronoUnit.SECONDS);
            to = Instant.parse(end).truncatedTo(java.time.temporal.ChronoUnit.SECONDS);
        } catch (Exception e) {
            throw new GoogleFailure(400, "INVALID_TIME", "Thời gian học không hợp lệ.");
        }
        var course = store.course(connections.subject(email), id);
        String subject = connections.subject(email), token = connections.access(email);
        String eventId = requestId.replace("-", "");
        var events = new ArrayList<>(maps(course.get("events")));
        var existing = events.stream().filter(e -> eventId.equals(e.get("id"))).findFirst().orElse(null);
        if (existing != null) {
            if (!sameTime(from, Map.of("dateTime", required(existing, "start"))) || !sameTime(to, Map.of("dateTime", required(existing, "end"))))
                throw new GoogleFailure(409, "CALENDAR_RETRY_CHANGED", "Mã thao tác này đã được dùng cho buổi học khác.");
            if (!eventId.equals(course.get("calendarEventId")))
                throw new GoogleFailure(409, "CALENDAR_OLD_SESSION", "Buổi này không còn là buổi đang chọn. Không tự đổi link về buổi cũ.");
            return syncCalendar(subject, course, token);
        }
        if (!string(course, "calendarEventId").isBlank() && (Set.of("PENDING", "CREATING").contains(string(course, "calendarStatus")) || !Boolean.TRUE.equals(course.get("calendarCreated"))))
            throw new GoogleFailure(409, "CALENDAR_PENDING", "Buổi trước đang chờ Google xác nhận. Bấm Đồng bộ để kiểm tra trước khi tạo thêm phòng.");
        if (!to.isAfter(from) || from.isBefore(Instant.now().minusSeconds(60)) || to.isAfter(from.plusSeconds(86400)))
            throw new GoogleFailure(400, "INVALID_TIME", "Chọn buổi học trong tương lai, kết thúc sau bắt đầu và không quá 24 giờ.");
        migrateMeetAccess(course, students(course));
        var attendees = students(course).stream().filter(s -> Boolean.TRUE.equals(s.get("meetAllowed"))).map(s -> Map.of("email", s.get("email"))).toList();
        if (attendees.isEmpty())
            throw new GoogleFailure(409, "NO_STUDENTS", "Thêm ít nhất một email học sinh trước khi chuẩn bị phòng.");
        var body = new LinkedHashMap<String, Object>();
        body.put("id", eventId);
        body.put("summary", course.get("title"));
        body.put("start", Map.of("dateTime", from.toString()));
        body.put("end", Map.of("dateTime", to.toString()));
        body.put("description", "Buổi học HocLuc. Đăng nhập đúng tài khoản Google được mời để tham gia Meet của sự kiện này.");
        body.put("extendedProperties", Map.of("private", Map.of("hoclucCourseId", id)));
        body.put("conferenceData", Map.of("createRequest", Map.of("requestId", requestId, "conferenceSolutionKey", Map.of("type", "hangoutsMeet"))));
        body.put("attendees", attendees);
        body.put("guestsCanInviteOthers", false);
        body.put("guestsCanSeeOtherGuests", false);

        course.putIfAbsent("legacyMeetingUrl", string(course, "meetingUrl"));
        course.put("admissionMode", "CALENDAR");
        course.put("calendarEventId", eventId);
        course.put("calendarStatus", "CREATING");
        course.remove("meetingUrl");
        course.remove("calendarCreated");
        course.remove("calendarUrl");
        course.put("calendarManagedEmails", attendees.stream().map(a -> a.get("email")).toList());

        var operation = new LinkedHashMap<String, Object>();
        operation.put("id", eventId);
        operation.put("start", from.toString());
        operation.put("end", to.toString());
        operation.put("request", body);
        operation.put("url", "");
        operation.put("inviteeCount", attendees.size());
        events.add(operation);
        course.put("events", events);
        store.saveCourse(subject, course);
        return createCalendarEvent(subject, course, token, operation);
    }

    public synchronized Map<String, Object> start(String email, String id, String requestId) {
        requireId(requestId);
        String subject = connections.subject(email);
        var course = store.course(subject, id);
        var now = Instant.now();
        var events = maps(course.get("events"));
        var active = classrooms.getActiveClassroom();
        String activeUrl = active != null && active.has("status") && "ONGOING".equals(active.get("status").getAsString()) && active.has("meetingUrl") ? active.get("meetingUrl").getAsString() : "";
        var ended = new HashSet<String>();
        var history = classrooms.getClassroomHistory(null);
        if (history != null) {
            for (var value : history) {
                var entry = value.getAsJsonObject();
                if (entry.has("meetingUrl")) ended.add(entry.get("meetingUrl").getAsString());
            }
        }
        Map<String, Object> selected = null;
        if (!activeUrl.isBlank()) {
            selected = events.stream().filter(e -> activeUrl.equals(e.get("meetingUrl")) || (string(course, "calendarEventId").equals(e.get("id")) && activeUrl.equals(course.get("meetingUrl")))).findFirst().orElse(null);
        }
        if (selected == null && !string(course, "calendarEventId").isBlank() && (!Boolean.TRUE.equals(course.get("calendarCreated")) || Set.of("PENDING", "CREATING", "VERIFY_FAILED").contains(string(course, "calendarStatus")))) {
            selected = events.stream().filter(e -> string(course, "calendarEventId").equals(e.get("id"))).findFirst().orElse(null);
        }
        if (selected == null) {
            selected = events.stream().filter(e -> map(e.get("request")).containsKey("conferenceData") && !ended.contains(eventMeetingUrl(course, e)) && !(string(course, "calendarEventId").equals(e.get("id")) && "FAILED".equals(course.get("calendarStatus"))))
                .filter(e -> Instant.parse(required(e, "end")).isAfter(now) && !Instant.parse(required(e, "start")).isAfter(now.plusSeconds(900)))
                .min(Comparator.<Map<String, Object>, Integer>comparing(e -> Instant.parse(required(e, "start")).isAfter(now) ? 1 : 0)
                    .thenComparing(e -> Math.abs(java.time.Duration.between(now, Instant.parse(required(e, "start"))).toSeconds())))
                .orElse(null);
        }
        if (selected == null) {
            if (events.stream().anyMatch(e -> requestId.replace("-", "").equals(e.get("id"))))
                throw new GoogleFailure(409, "START_REQUEST_FINISHED", "Buổi của lần bấm trước đã kết thúc. Tải lại danh sách để bắt đầu buổi mới.");
            return schedule(email, id, requestId, now.toString(), now.plusSeconds(5400).toString());
        }
        course.put("admissionMode", "CALENDAR");
        course.put("calendarEventId", selected.get("id"));
        var managed = new HashSet<String>();
        for (var attendee : maps(map(selected.get("request")).get("attendees"))) managed.add(string(attendee, "email"));
        if (selected.get("managedEmails") instanceof List<?> list) {
            for (var value : list) managed.add(value.toString());
        }
        course.put("calendarManagedEmails", managed);
        store.saveCourse(subject, course);
        return syncCalendar(subject, course, connections.access(email));
    }

    public Map<String, Object> syncCalendar(String subject, Map<String, Object> course, String token) {
        var warnings = new ArrayList<String>();
        var rows = students(course);
        course.put("accessNotice", "HocLuc sẽ kiểm tra phòng và danh sách email trước khi mở buổi dạy. Học sinh dùng link của buổi hiện tại.");
        if (string(course, "calendarEventId").isBlank()) {
            course.put("calendarStatus", "NOT_PREPARED");
            course.remove("meetingUrl");
            for (var row : rows) row.put("meetStatus", "NOT_GRANTED");
            course.put("warnings", List.of());
            course.put("accessNotice", "Thêm email rồi bấm Bắt đầu dạy. HocLuc sẽ tự chuẩn bị phòng và gửi lời mời.");
            store.saveCourse(subject, course);
            return course;
        }
        try {
            String eventId = required(course, "calendarEventId");
            var operation = maps(course.get("events")).stream().filter(e -> eventId.equals(e.get("id"))).findFirst().orElseThrow();
            Map<String, Object> event;
            try {
                event = google.call("GET", CALENDAR + "/" + eventId, token, null);
            } catch (GoogleFailure e) {
                if (e.code.equals("GOOGLE_404") && !Boolean.TRUE.equals(course.get("calendarCreated")))
                    return createCalendarEvent(subject, course, token, operation);
                throw e;
            }
            validateCalendarEvent(course, event, operation);
            course.put("calendarCreated", true);
            operation.put("url", string(event, "htmlLink"));
            operation.put("inviteeCount", maps(event.get("attendees")).size());
            var desired = new TreeSet<String>();
            for (var row : rows) if (Boolean.TRUE.equals(row.get("meetAllowed"))) desired.add(string(row, "email"));
            var managed = new HashSet<String>();
            if (course.get("calendarManagedEmails") instanceof List<?> list) for (var value : list) managed.add(value.toString());
            var attendees = new ArrayList<>(maps(event.get("attendees")));
            var actual = new TreeSet<String>();
            for (var attendee : attendees) actual.add(string(attendee, "email").toLowerCase(Locale.ROOT));
            var target = new TreeSet<>(actual);
            target.removeAll(managed);
            target.addAll(desired);
            if (!target.equals(actual)) {
                attendees.removeIf(a -> managed.contains(string(a, "email").toLowerCase(Locale.ROOT)) && !desired.contains(string(a, "email").toLowerCase(Locale.ROOT)));
                for (String address : desired) if (!actual.contains(address)) attendees.add(new LinkedHashMap<>(Map.of("email", address)));
                managed.addAll(desired);
                course.put("calendarManagedEmails", managed);
                store.saveCourse(subject, course);
                operation.put("managedEmails", managed);
                store.saveCourse(subject, course);
                google.call("PATCH", CALENDAR + "/" + eventId + "?conferenceDataVersion=1&sendUpdates=all", token, Map.of("attendees", attendees));
                event = google.call("GET", CALENDAR + "/" + eventId, token, null);
                validateCalendarEvent(course, event, operation);
            }
            var confirmed = new HashSet<String>();
            for (var attendee : maps(event.get("attendees"))) confirmed.add(string(attendee, "email").toLowerCase(Locale.ROOT));
            if (!confirmed.equals(target))
                throw new GoogleFailure(502, "CALENDAR_ATTENDEES_UNCONFIRMED", "Google chưa xác nhận thay đổi danh sách khách mời. Bấm Đồng bộ để kiểm tra lại.");
            var conference = map(event.get("conferenceData"));
            String state = string(map(map(conference.get("createRequest")).get("status")), "statusCode");
            String link = "";
            if ("hangoutsMeet".equals(string(map(map(conference.get("conferenceSolution")).get("key")), "type"))) {
                for (var entry : maps(conference.get("entryPoints"))) if ("video".equals(entry.get("entryPointType"))) link = string(entry, "uri");
            }
            if (!link.matches("https://meet\\.google\\.com/[a-z]{3}-[a-z]{4}-[a-z]{3}")) {
                course.remove("meetingUrl");
                course.put("calendarStatus", "failure".equals(state) ? "FAILED" : "PENDING");
                warnings.add("failure".equals(state) ? "Google không tạo được phòng. Bấm Thử lại để chuẩn bị lại buổi học." : "Google đang chuẩn bị phòng. HocLuc sẽ tự kiểm tra lại; nếu chưa xong, bấm Thử lại để tiếp tục.");
            } else {
                course.put("meetingUrl", link);
                course.put("calendarStatus", "READY");
                course.put("calendarUrl", string(event, "htmlLink"));
                operation.put("meetingUrl", link);
            }
            for (var row : rows) {
                row.put("meetStatus", Boolean.TRUE.equals(row.get("meetAllowed")) ? "CALENDAR_INVITED" : confirmed.contains(string(row, "email")) ? "EXTERNAL_ACCESS" : "NOT_GRANTED");
                row.remove("error");
            }
            course.put("accessNotice", "Lời mời của buổi học đã được cập nhật. Học sinh dùng đúng email được mời và link của buổi hiện tại.");
        } catch (GoogleFailure failure) {
            warnings.add(failure.getMessage());
            course.put("calendarStatus", "VERIFY_FAILED");
            for (var row : rows) {
                row.put("meetStatus", "VERIFY_FAILED");
                row.put("error", failure.getMessage());
            }
        }
        course.put("warnings", warnings);
        course.put("syncedAt", Instant.now().toString());
        store.saveCourse(subject, course);
        return course;
    }

    private Map<String, Object> createCalendarEvent(String subject, Map<String, Object> course, String token, Map<String, Object> operation) {
        String eventId = required(operation, "id");
        Map<String, Object> event;
        try {
            event = google.call("POST", CALENDAR + "?conferenceDataVersion=1&sendUpdates=all", token, map(operation.get("request")));
        } catch (GoogleFailure e) {
            if (!e.code.equals("GOOGLE_409")) throw e;
            event = google.call("GET", CALENDAR + "/" + eventId, token, null);
        }
        validateCalendarEvent(course, event, operation);
        course.put("calendarCreated", true);
        course.put("calendarStatus", "PENDING");
        store.saveCourse(subject, course);
        return syncCalendar(subject, course, token);
    }

    private void validateCalendarEvent(Map<String, Object> course, Map<String, Object> event, Map<String, Object> operation) {
        if (!string(operation, "id").equals(string(event, "id"))
            || !string(course, "id").equals(string(map(map(event.get("extendedProperties")).get("private")), "hoclucCourseId"))
            || !sameTime(Instant.parse(required(operation, "start")), map(event.get("start")))
            || !sameTime(Instant.parse(required(operation, "end")), map(event.get("end")))
            || "cancelled".equals(event.get("status")))
            throw new GoogleFailure(409, "CALENDAR_EVENT_MISMATCH", "Sự kiện Google không khớp buổi học HocLuc. Chưa sử dụng link phòng.");
        if (Boolean.TRUE.equals(event.get("attendeesOmitted")))
            throw new GoogleFailure(502, "CALENDAR_INCOMPLETE", "Google chưa trả đủ khách mời. Chưa xác nhận danh sách email.");
    }

    public void requireReady(Map<String, Object> course) {
        if ("CALENDAR".equals(course.get("admissionMode"))) {
            if (!"READY".equals(course.get("calendarStatus")) || string(course, "meetingUrl").isBlank() || !(course.get("warnings") instanceof List<?> warnings) || !warnings.isEmpty())
                throw new GoogleFailure(409, "CALENDAR_NOT_READY", "Phòng Calendar chưa sẵn sàng. Bấm Đồng bộ và kiểm tra thông báo.");
            var event = maps(course.get("events")).stream().filter(e -> string(course, "calendarEventId").equals(e.get("id"))).findFirst().orElseThrow();
            if (!Instant.parse(required(event, "end")).isAfter(Instant.now()))
                throw new GoogleFailure(409, "CALENDAR_ENDED", "Buổi Calendar này đã kết thúc. Chuẩn bị phòng cho buổi mới.");
            return;
        }
        if (string(course, "meetingUrl").isBlank() || !Set.of("RESTRICTED", "TRUSTED").contains(string(course, "accessType")) || maps(course.get("students")).stream().anyMatch(s -> Boolean.TRUE.equals(s.get("meetAllowed")) && !"GRANTED".equals(s.get("meetStatus")))
            || !(course.get("warnings") instanceof List<?> warnings) || !warnings.isEmpty())
            throw new GoogleFailure(409, "CLASS_NOT_READY", "Lớp chưa sẵn sàng. Đồng bộ và xử lý các thông báo trước khi bắt đầu hoặc gửi lịch.");
    }

    static String eventMeetingUrl(Map<String, Object> course, Map<String, Object> event) {
        String url = string(event, "meetingUrl");
        return url.isBlank() && string(course, "calendarEventId").equals(event.get("id")) ? string(course, "meetingUrl") : url;
    }

    static void migrateMeetAccess(Map<String, Object> course, List<Map<String, Object>> students) {
        var intended = course.get("intendedEmails") instanceof List<?> list ? list : List.of();
        for (var row : students) {
            if (!row.containsKey("meetAllowed")) {
                row.put("meetAllowed", intended.contains(row.get("email"))
                    || !string(row, "invitationId").isBlank() || Set.of("INVITED", "INVITE_FAILED", "NOT_INVITED").contains(string(row, "classroomStatus")));
            }
        }
    }

    static boolean sameTime(Instant expected, Map<String, Object> time) {
        try {
            return expected.truncatedTo(java.time.temporal.ChronoUnit.SECONDS).equals(java.time.OffsetDateTime.parse(string(time, "dateTime")).toInstant().truncatedTo(java.time.temporal.ChronoUnit.SECONDS));
        } catch (Exception e) {
            return false;
        }
    }

    static void requireId(String id) {
        if (id == null || !id.matches("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"))
            throw new GoogleFailure(400, "INVALID_REQUEST", "Mã thao tác không hợp lệ.");
    }

    static String required(Map<String, Object> value, String key) {
        String result = string(value, key);
        if (result.isBlank()) throw new GoogleFailure(502, "GOOGLE_RESPONSE", "Google chưa trả đủ thông tin. Đồng bộ lại để kiểm tra.");
        return result;
    }

    @SuppressWarnings("unchecked")
    static Map<String, Object> map(Object value) {
        return value instanceof Map ? (Map<String, Object>) value : Map.of();
    }

    @SuppressWarnings("unchecked")
    static List<Map<String, Object>> maps(Object value) {
        return value instanceof List ? (List<Map<String, Object>>) value : List.of();
    }

    static List<Map<String, Object>> students(Map<String, Object> course) {
        return new ArrayList<>(maps(course.get("students")));
    }
}
