package vn.teaching.integrations;

import org.springframework.stereotype.Service;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.*;
import static vn.teaching.integrations.GoogleConnectionService.*;

/** Orchestrates independent providers. Classroom courses are mapped to app-created Meet spaces. */
@Service
public class GoogleClassService {
    private static final String CLASSROOM="https://classroom.googleapis.com/v1/";
    private static final String MEET="https://meet.googleapis.com/v2/";
    private static final String CALENDAR="https://www.googleapis.com/calendar/v3/calendars/primary/events";
    private final GoogleConnectionService connections;
    private final GoogleGateway google;
    private final GoogleStore store;
    private final vn.teaching.service.ClassroomService classrooms;
    public GoogleClassService(GoogleConnectionService connections, GoogleGateway google, GoogleStore store, vn.teaching.service.ClassroomService classrooms) {
        this.connections=connections; this.google=google; this.store=store;
        this.classrooms=classrooms;
    }
    public List<Map<String,Object>> list(String email) { return store.courses(connections.subject(email)); }
    public synchronized Map<String,Object> create(String email,String requestId,String title,String description,List<String> emails) {
        requireId(requestId); title=title==null?"":title.trim();
        if(title.isEmpty() || title.length()>200 || (description!=null && description.length()>2000))
            throw new GoogleFailure(400,"INVALID_CLASS","Tên lớp từ 1–200 ký tự, mô tả tối đa 2000 ký tự.");
        var normalized=emails(emails); String subject=connections.subject(email);
        Map<String,Object> course=store.courses(subject).stream().filter(c -> requestId.equals(c.get("id"))).findFirst().orElse(null);
        if(course==null) {
            course=new LinkedHashMap<>(); course.put("id",requestId); course.put("title",title); course.put("description",description==null?"":description);
            course.put("admissionMode","CALENDAR");
            course.put("students",new ArrayList<>()); course.put("warnings",new ArrayList<>()); store.saveCourse(subject,course);
            course.put("intendedEmails",normalized); store.saveCourse(subject,course);
        }
        String token=connections.access(email);
        if(string(course,"courseId").isBlank()) {
            String alias="p:hocluc-"+requestId;
            Map<String,Object> remote;
            // Consumer Gmail accounts cannot create ACTIVE courses directly.
            try { remote=google.call("POST",CLASSROOM+"courses",token,Map.of("id",alias,"name",course.get("title"),"description",course.get("description"),"ownerId","me","courseState","PROVISIONED")); }
            catch(GoogleFailure e) {
                if(e.code.equals("GOOGLE_409")) remote=google.call("GET",CLASSROOM+"courses/"+encode(alias),token,null);
                else { remote=Map.of(); course.put("classroomWarnings",List.of("Chưa tạo được Classroom: "+e.getMessage())); }
            }
            if(!string(remote,"id").isBlank()) {
                course.put("courseId",required(remote,"id")); course.put("classroomUrl",string(remote,"alternateLink"));
                course.put("classroomState",remote.getOrDefault("courseState","PROVISIONED"));
            }
            store.saveCourse(subject,course);
        }
        // Keep creation resumable even if individual invitations or Meet fail.
        var students=students(course);
        for(String studentEmail:normalized) {
            if(students.stream().noneMatch(s -> studentEmail.equals(s.get("email")))) {
                var student=new LinkedHashMap<String,Object>(); student.put("email",studentEmail); student.put("name",studentEmail);
                student.put("classroomStatus","NOT_INVITED"); student.put("meetStatus","NOT_GRANTED"); students.add(student);
            }
        }
        for(var student:students) if(normalized.contains(string(student,"email"))) student.put("meetAllowed",true);
        course.put("students",students); store.saveCourse(subject,course);
        if(string(course,"courseId").isBlank()) return sync(email,requestId);
        if(!"ACTIVE".equals(course.get("classroomState"))) {
            try {
                var active=google.call("PATCH",CLASSROOM+"courses/"+encode(required(course,"courseId"))+"?updateMask=courseState",token,Map.of("courseState","ACTIVE"));
                course.put("classroomState",required(active,"courseState"));
                store.saveCourse(subject,course);
                if(!"ACTIVE".equals(course.get("classroomState"))) return awaitingActivation(subject,course,null,token);
            } catch(GoogleFailure e) { return awaitingActivation(subject,course,e.getMessage(),token); }
        }
        return inviteAndSync(email,course,normalized);
    }
    public synchronized Map<String,Object> invite(String email,String id,List<String> requested) {
        var course=store.course(connections.subject(email),id);
        return inviteAndSync(email,course,emails(requested));
    }
    private Map<String,Object> inviteAndSync(String email,Map<String,Object> course,List<String> requested) {
        String subject=connections.subject(email);
        var students=students(course);
        for(String studentEmail:requested) {
            var student=students.stream().filter(row -> studentEmail.equals(row.get("email"))).findFirst().orElse(null);
            if(student==null) {
                student=new LinkedHashMap<>(); student.put("email",studentEmail); student.put("name",studentEmail);
                student.put("classroomStatus","NOT_INVITED"); student.put("meetStatus","NOT_GRANTED"); students.add(student);
            }
            student.put("meetAllowed",true);
        }
        course.put("students",students); store.saveCourse(subject,course);
        return sync(email,string(course,"id"));
    }
    public synchronized Map<String,Object> setMeetAccess(String email,String id,String studentEmail,boolean allowed) {
        studentEmail=normalizeEmail(studentEmail);
        String subject=connections.subject(email); var course=store.course(subject,id);
        String selected=studentEmail;
        var row=students(course).stream().filter(s -> selected.equals(s.get("email"))).findFirst()
            .orElseThrow(() -> new GoogleFailure(404,"STUDENT_NOT_FOUND","Không tìm thấy email trong lớp."));
        row.put("meetAllowed",allowed); store.saveCourse(subject,course);
        return sync(email,id);
    }
    public synchronized Map<String,Object> sync(String email,String id) {
        String subject=connections.subject(email),token=connections.access(email); var course=store.course(subject,id);
        var students=students(course); var classroomWarnings=new ArrayList<String>();
        // Migrate only emails explicitly entered/invited by the teacher, never a whole imported roster.
        migrateMeetAccess(course,students);
        try {
            if(string(course,"courseId").isBlank()) throw new GoogleFailure(409,"CREATE_INCOMPLETE","Classroom chưa tạo xong; quyền Meet vẫn được xử lý riêng.");
            if(course.containsKey("classroomState") && !"ACTIVE".equals(course.get("classroomState"))) {
                var remote=google.call("GET",CLASSROOM+"courses/"+encode(string(course,"courseId")),token,null);
                course.put("classroomState",required(remote,"courseState"));
                if(!"ACTIVE".equals(course.get("classroomState"))) throw new GoogleFailure(409,"CLASSROOM_NOT_ACTIVE","Mở Classroom để chấp nhận lớp; không cần chấp nhận Classroom để được cấp quyền Meet.");
            }
            var roster=pages(CLASSROOM+"courses/"+encode(string(course,"courseId"))+"/students","students",token);
            var invitations=pages(CLASSROOM+"invitations?courseId="+encode(string(course,"courseId")),"invitations",token);
            Set<String> joined=new HashSet<>(),pending=new HashSet<>();
            for(var invitation:invitations) if("STUDENT".equals(invitation.get("role"))) pending.add(string(invitation,"id"));
            for(var remote:roster) {
                String studentEmail=profileEmail(remote);
                if(studentEmail.isBlank()) throw new GoogleFailure(502,"ROSTER_EMAIL_MISSING","Classroom không trả email; trạng thái Meet được kiểm tra riêng.");
                joined.add(studentEmail);
                var row=students.stream().filter(v -> studentEmail.equals(v.get("email"))).findFirst().orElse(null);
                if(row==null) { row=new LinkedHashMap<>(); row.put("email",studentEmail); row.put("meetAllowed",false); row.put("meetStatus","NOT_GRANTED"); students.add(row); }
                row.put("name",map(map(remote.get("profile")).get("name")).getOrDefault("fullName",studentEmail));
                row.put("googleUserId",string(remote,"userId")); row.put("classroomStatus","JOINED"); row.remove("classroomError");
            }
            for(var row:students) {
                if(joined.contains(row.get("email"))) continue;
                if("JOINED".equals(row.get("classroomStatus"))) row.put("classroomStatus","LEFT");
                else if("INVITED".equals(row.get("classroomStatus")) && !string(row,"invitationId").isBlank() && !pending.contains(row.get("invitationId"))) row.put("classroomStatus","INVITATION_CLOSED");
                if(!Boolean.TRUE.equals(row.get("meetAllowed")) || !Set.of("NOT_INVITED","INVITE_FAILED").contains(string(row,"classroomStatus"))) continue;
                try {
                    var invitation=google.call("POST",CLASSROOM+"invitations",token,Map.of("courseId",course.get("courseId"),"userId",row.get("email"),"role","STUDENT"));
                    row.put("invitationId",required(invitation,"id")); row.put("classroomStatus","INVITED"); row.remove("classroomError");
                } catch(GoogleFailure failure) {
                    row.put("classroomStatus",failure.code.equals("GOOGLE_409")?"INVITED":"INVITE_FAILED");
                    row.put("classroomError",failure.getMessage()); classroomWarnings.add(string(row,"email")+": Classroom: "+failure.getMessage());
                }
            }
        } catch(GoogleFailure failure) { classroomWarnings.add(failure.getMessage()); }
        course.put("classroomWarnings",classroomWarnings); course.put("students",students); store.saveCourse(subject,course);
        return syncMeet(subject,course,token);
    }
    private Map<String,Object> syncMeet(String subject,Map<String,Object> course,String token) {
        if("CALENDAR".equals(course.get("admissionMode"))) return syncCalendar(subject,course,token);
        var rows=students(course); var warnings=new ArrayList<String>();
        migrateMeetAccess(course,rows);
        try {
            if(string(course,"spaceName").isBlank()) {
                if(Boolean.TRUE.equals(course.get("meetCreationUncertain"))) throw new GoogleFailure(409,"MEET_UNCERTAIN","Chưa xác định được kết quả tạo Meet. Không tự tạo lại để tránh phòng trùng.");
                Map<String,Object> space;
                try {
                    try { space=google.call("POST",MEET+"spaces",token,Map.of("config",Map.of("accessType","RESTRICTED"))); }
                    catch(GoogleFailure unsupported) {
                        if(!unsupported.code.equals("GOOGLE_FAILED_PRECONDITION")) throw unsupported;
                        space=google.call("POST",MEET+"spaces",token,Map.of("config",Map.of("accessType","TRUSTED")));
                        course.put("restrictedRetryAfter",System.currentTimeMillis()+86_400_000L);
                    }
                }
                catch(GoogleFailure failure) {
                if(failure.code.equals("GOOGLE_NETWORK") || failure.code.matches("GOOGLE_5[0-9][0-9]")) course.put("meetCreationUncertain",true);
                    throw failure;
                }
                course.put("spaceName",required(space,"name")); course.put("meetingUrl",required(space,"meetingUri")); store.saveCourse(subject,course);
            }
            String space=required(course,"spaceName");
            var settings=google.call("GET",MEET+space,token,null);
            String currentAccess=string(map(settings.get("config")),"accessType");
            long retryAfter=course.get("restrictedRetryAfter") instanceof Number n ? n.longValue() : 0;
            if(!"RESTRICTED".equals(currentAccess) && !("TRUSTED".equals(currentAccess) && retryAfter>System.currentTimeMillis())) {
                try {
                    google.call("PATCH",MEET+space+"?updateMask=config.accessType",token,Map.of("name",space,"config",Map.of("accessType","RESTRICTED")));
                } catch(GoogleFailure failure) {
                    if(!failure.code.equals("GOOGLE_FAILED_PRECONDITION") || !"TRUSTED".equals(currentAccess)) throw failure;
                    course.put("restrictedRetryAfter",System.currentTimeMillis()+86_400_000L);
                }
            }
            var members=pages(MEET+space+"/members","members",token);
            boolean changed=false;
            for(var row:rows) {
                String studentEmail=string(row,"email");
                var member=members.stream().filter(m -> studentEmail.equalsIgnoreCase(string(m,"email"))).findFirst().orElse(null);
                boolean allowed=Boolean.TRUE.equals(row.get("meetAllowed"));
                boolean owned=Boolean.TRUE.equals(row.get("grantAttempted"));
                try {
                    if(allowed && member==null) {
                        row.put("grantAttempted",true); row.put("meetStatus","VERIFYING"); store.saveCourse(subject,course); changed=true;
                        google.call("POST",MEET+space+"/members",token,Map.of("email",studentEmail,"role","ROLE_UNSPECIFIED"));
                    } else if(!allowed && owned && member!=null) {
                        changed=true;
                        google.call("DELETE",MEET+required(member,"name"),token,null);
                    }
                } catch(GoogleFailure failure) {
                    row.put("meetStatus",allowed?"GRANT_FAILED":"REVOKE_FAILED"); row.put("error",failure.getMessage());
                }
            }
            // A POST/DELETE response alone is not proof. Reconcile the complete remote list.
            if(changed) members=pages(MEET+space+"/members","members",token);
            for(var row:rows) {
                String studentEmail=string(row,"email");
                var member=members.stream().filter(m -> studentEmail.equalsIgnoreCase(string(m,"email"))).findFirst().orElse(null);
                boolean allowed=Boolean.TRUE.equals(row.get("meetAllowed")),owned=Boolean.TRUE.equals(row.get("grantAttempted"));
                if(allowed && member!=null && string(member,"name").startsWith(space+"/members/")) {
                    row.put("memberName",member.get("name")); row.put("meetStatus","GRANTED"); row.remove("error");
                } else if(!allowed && member==null) {
                    row.remove("memberName"); row.remove("grantAttempted"); row.remove("error"); row.put("meetStatus","NOT_GRANTED");
                } else {
                    row.put("meetStatus",allowed?"GRANT_FAILED":owned?"REVOKE_FAILED":"EXTERNAL_ACCESS");
                    String detail=allowed?"Google chưa xác nhận quyền vào Meet. Bấm Đồng bộ để thử lại.":owned?"Google chưa xác nhận thu hồi quyền Meet.":"Email còn membership ngoài quyền do HocLuc quản lý. Kiểm tra trong Google Meet.";
                    if(!row.containsKey("error")) row.put("error",detail);
                    warnings.add(studentEmail+": "+row.get("error"));
                }
            }
            var confirmed=google.call("GET",MEET+space,token,null);
            course.put("accessType",string(map(confirmed.get("config")),"accessType"));
            if("RESTRICTED".equals(course.get("accessType"))) { course.remove("accessNotice"); course.remove("restrictedRetryAfter"); }
            else if("TRUSTED".equals(course.get("accessType"))) course.put("accessNotice","Google dùng chế độ Trusted cho phòng này. Quyền vào của từng email được xác nhận qua Meet membership; các quyền vào khác do Google quản lý vẫn có hiệu lực.");
            else warnings.add("Google chưa xác nhận cấu hình Restricted hoặc Trusted. Chưa thể xác nhận quyền vào theo email.");
        } catch(GoogleFailure failure) {
            warnings.add(failure.getMessage());
            for(var row:rows) if(Boolean.TRUE.equals(row.get("meetAllowed"))) {
                row.put("meetStatus","VERIFY_FAILED"); row.put("error",failure.getMessage());
            } else if(Boolean.TRUE.equals(row.get("grantAttempted"))) {
                row.put("meetStatus","REVOKE_FAILED"); row.put("error",failure.getMessage());
            }
        }
        course.put("warnings",warnings); course.put("syncedAt",Instant.now().toString());
        store.saveCourse(subject,course); return course;
    }
    public synchronized Map<String,Object> schedule(String email,String id,String requestId,String start,String end) {
        requireId(requestId); Instant from,to;
        try { from=Instant.parse(start).truncatedTo(java.time.temporal.ChronoUnit.SECONDS); to=Instant.parse(end).truncatedTo(java.time.temporal.ChronoUnit.SECONDS); } catch(Exception e) { throw new GoogleFailure(400,"INVALID_TIME","Thời gian học không hợp lệ."); }
        var course=store.course(connections.subject(email),id);
        String subject=connections.subject(email), token=connections.access(email);
        String eventId=requestId.replace("-","");
        var events=new ArrayList<>(maps(course.get("events")));
        var existing=events.stream().filter(e -> eventId.equals(e.get("id"))).findFirst().orElse(null);
        if(existing!=null) {
            if(!sameTime(from,Map.of("dateTime",required(existing,"start"))) || !sameTime(to,Map.of("dateTime",required(existing,"end"))))
                throw new GoogleFailure(409,"CALENDAR_RETRY_CHANGED","Mã thao tác này đã được dùng cho buổi học khác.");
            if(!eventId.equals(course.get("calendarEventId"))) throw new GoogleFailure(409,"CALENDAR_OLD_SESSION","Buổi này không còn là buổi đang chọn. Không tự đổi link về buổi cũ.");
            return syncCalendar(subject,course,token);
        }
        if(!string(course,"calendarEventId").isBlank() && (Set.of("PENDING","CREATING").contains(string(course,"calendarStatus")) || !Boolean.TRUE.equals(course.get("calendarCreated"))))
            throw new GoogleFailure(409,"CALENDAR_PENDING","Buổi trước đang chờ Google xác nhận. Bấm Đồng bộ để kiểm tra trước khi tạo thêm phòng.");
        if(!to.isAfter(from) || from.isBefore(Instant.now().minusSeconds(60)) || to.isAfter(from.plusSeconds(86400)))
            throw new GoogleFailure(400,"INVALID_TIME","Chọn buổi học trong tương lai, kết thúc sau bắt đầu và không quá 24 giờ.");
        migrateMeetAccess(course,students(course));
        var attendees=students(course).stream().filter(s -> Boolean.TRUE.equals(s.get("meetAllowed"))).map(s -> Map.of("email",s.get("email"))).toList();
        if(attendees.isEmpty()) throw new GoogleFailure(409,"NO_STUDENTS","Thêm ít nhất một email học sinh trước khi chuẩn bị phòng.");
        var body=new LinkedHashMap<String,Object>(); body.put("id",eventId); body.put("summary",course.get("title"));
        body.put("start",Map.of("dateTime",from.toString())); body.put("end",Map.of("dateTime",to.toString()));
        body.put("description","Buổi học HocLuc. Đăng nhập đúng tài khoản Google được mời để tham gia Meet của sự kiện này.");
        body.put("extendedProperties",Map.of("private",Map.of("hoclucCourseId",id)));
        body.put("conferenceData",Map.of("createRequest",Map.of("requestId",requestId,"conferenceSolutionKey",Map.of("type","hangoutsMeet"))));
        body.put("attendees",attendees); body.put("guestsCanInviteOthers",false); body.put("guestsCanSeeOtherGuests",false);
        // Persist the exact operation before the network call, including timeouts with unknown outcome.
        course.putIfAbsent("legacyMeetingUrl",string(course,"meetingUrl"));
        course.put("admissionMode","CALENDAR"); course.put("calendarEventId",eventId);
        course.put("calendarStatus","CREATING"); course.remove("meetingUrl");
        course.remove("calendarCreated"); course.remove("calendarUrl");
        course.put("calendarManagedEmails",attendees.stream().map(a -> a.get("email")).toList());
        var operation=new LinkedHashMap<String,Object>(); operation.put("id",eventId); operation.put("start",from.toString()); operation.put("end",to.toString()); operation.put("request",body);
        operation.put("url",""); operation.put("inviteeCount",attendees.size());
        events.add(operation); course.put("events",events); store.saveCourse(subject,course);
        return createCalendarEvent(subject,course,token,operation);
    }
    private Map<String,Object> createCalendarEvent(String subject,Map<String,Object> course,String token,Map<String,Object> operation) {
        String eventId=required(operation,"id");
        Map<String,Object> event;
        try { event=google.call("POST",CALENDAR+"?conferenceDataVersion=1&sendUpdates=all",token,map(operation.get("request"))); }
        catch(GoogleFailure e) {
            if(!e.code.equals("GOOGLE_409")) throw e;
            event=google.call("GET",CALENDAR+"/"+eventId,token,null);
        }
        validateCalendarEvent(course,event,operation);
        course.put("calendarCreated",true);
        course.put("calendarStatus","PENDING"); store.saveCourse(subject,course);
        // Read the authoritative event: conference creation is asynchronous.
        return syncCalendar(subject,course,token);
    }
    private void validateCalendarEvent(Map<String,Object> course,Map<String,Object> event,Map<String,Object> operation) {
        if(!string(operation,"id").equals(string(event,"id"))
            || !string(course,"id").equals(string(map(map(event.get("extendedProperties")).get("private")),"hoclucCourseId"))
            || !sameTime(Instant.parse(required(operation,"start")),map(event.get("start")))
            || !sameTime(Instant.parse(required(operation,"end")),map(event.get("end")))
            || "cancelled".equals(event.get("status")))
            throw new GoogleFailure(409,"CALENDAR_EVENT_MISMATCH","Sự kiện Google không khớp buổi học HocLuc. Chưa sử dụng link phòng.");
        if(Boolean.TRUE.equals(event.get("attendeesOmitted")))
            throw new GoogleFailure(502,"CALENDAR_INCOMPLETE","Google chưa trả đủ khách mời. Chưa xác nhận danh sách email.");
    }
    private Map<String,Object> syncCalendar(String subject,Map<String,Object> course,String token) {
        var warnings=new ArrayList<String>(); var rows=students(course);
        course.put("accessNotice","HocLuc sẽ kiểm tra phòng và danh sách email trước khi mở buổi dạy. Học sinh dùng link của buổi hiện tại.");
        if(string(course,"calendarEventId").isBlank()) {
            course.put("calendarStatus","NOT_PREPARED"); course.remove("meetingUrl");
            for(var row:rows) row.put("meetStatus","NOT_GRANTED");
            course.put("warnings",List.of()); course.put("accessNotice","Thêm email rồi bấm Bắt đầu dạy. HocLuc sẽ tự chuẩn bị phòng và gửi lời mời.");
            store.saveCourse(subject,course); return course;
        }
        try {
            String eventId=required(course,"calendarEventId");
            var operation=maps(course.get("events")).stream().filter(e -> eventId.equals(e.get("id"))).findFirst().orElseThrow();
            Map<String,Object> event;
            try { event=google.call("GET",CALENDAR+"/"+eventId,token,null); }
            catch(GoogleFailure e) {
                if(e.code.equals("GOOGLE_404") && !Boolean.TRUE.equals(course.get("calendarCreated"))) return createCalendarEvent(subject,course,token,operation);
                throw e;
            }
            validateCalendarEvent(course,event,operation);
            course.put("calendarCreated",true);
            operation.put("url",string(event,"htmlLink")); operation.put("inviteeCount",maps(event.get("attendees")).size());
            var desired=new TreeSet<String>();
            for(var row:rows) if(Boolean.TRUE.equals(row.get("meetAllowed"))) desired.add(string(row,"email"));
            var managed=new HashSet<String>();
            if(course.get("calendarManagedEmails") instanceof List<?> list) for(var value:list) managed.add(value.toString());
            var attendees=new ArrayList<>(maps(event.get("attendees")));
            var actual=new TreeSet<String>(); for(var attendee:attendees) actual.add(string(attendee,"email").toLowerCase(Locale.ROOT));
            var target=new TreeSet<>(actual); target.removeAll(managed); target.addAll(desired);
            if(!target.equals(actual)) {
                attendees.removeIf(a -> managed.contains(string(a,"email").toLowerCase(Locale.ROOT)) && !desired.contains(string(a,"email").toLowerCase(Locale.ROOT)));
                for(String address:desired) if(!actual.contains(address)) attendees.add(new LinkedHashMap<>(Map.of("email",address)));
                managed.addAll(desired); course.put("calendarManagedEmails",managed); store.saveCourse(subject,course);
                operation.put("managedEmails",managed); store.saveCourse(subject,course);
                google.call("PATCH",CALENDAR+"/"+eventId+"?conferenceDataVersion=1&sendUpdates=all",token,Map.of("attendees",attendees));
                event=google.call("GET",CALENDAR+"/"+eventId,token,null); validateCalendarEvent(course,event,operation);
            }
            var confirmed=new HashSet<String>(); for(var attendee:maps(event.get("attendees"))) confirmed.add(string(attendee,"email").toLowerCase(Locale.ROOT));
            if(!confirmed.equals(target)) throw new GoogleFailure(502,"CALENDAR_ATTENDEES_UNCONFIRMED","Google chưa xác nhận thay đổi danh sách khách mời. Bấm Đồng bộ để kiểm tra lại.");
            var conference=map(event.get("conferenceData"));
            String state=string(map(map(conference.get("createRequest")).get("status")),"statusCode");
            String link="";
            if("hangoutsMeet".equals(string(map(map(conference.get("conferenceSolution")).get("key")),"type"))) {
                for(var entry:maps(conference.get("entryPoints"))) if("video".equals(entry.get("entryPointType"))) link=string(entry,"uri");
            }
            if(!link.matches("https://meet\\.google\\.com/[a-z]{3}-[a-z]{4}-[a-z]{3}")) {
                course.remove("meetingUrl"); course.put("calendarStatus","failure".equals(state)?"FAILED":"PENDING");
                warnings.add("failure".equals(state)?"Google không tạo được phòng. Bấm Thử lại để chuẩn bị lại buổi học.":"Google đang chuẩn bị phòng. HocLuc sẽ tự kiểm tra lại; nếu chưa xong, bấm Thử lại để tiếp tục.");
            } else {
                course.put("meetingUrl",link); course.put("calendarStatus","READY"); course.put("calendarUrl",string(event,"htmlLink"));
                operation.put("meetingUrl",link);
            }
            for(var row:rows) { row.put("meetStatus",Boolean.TRUE.equals(row.get("meetAllowed"))?"CALENDAR_INVITED":confirmed.contains(string(row,"email"))?"EXTERNAL_ACCESS":"NOT_GRANTED"); row.remove("error"); }
            course.put("accessNotice","Lời mời của buổi học đã được cập nhật. Học sinh dùng đúng email được mời và link của buổi hiện tại.");
        } catch(GoogleFailure failure) {
            warnings.add(failure.getMessage()); course.put("calendarStatus","VERIFY_FAILED");
            for(var row:rows) { row.put("meetStatus","VERIFY_FAILED"); row.put("error",failure.getMessage()); }
        }
        course.put("warnings",warnings); course.put("syncedAt",Instant.now().toString()); store.saveCourse(subject,course); return course;
    }
    public Map<String,Object> prepare(String email,String id) {
        var course=sync(email,id); requireReady(course); return course;
    }
    /** One user action, resumable across network failures and app restarts. */
    public synchronized Map<String,Object> start(String email,String id,String requestId) {
        requireId(requestId);
        String subject=connections.subject(email); var course=store.course(subject,id);
        var now=Instant.now(); var events=maps(course.get("events"));
        var active=classrooms.getActiveClassroom();
        String activeUrl=active!=null && active.has("status") && "ONGOING".equals(active.get("status").getAsString()) && active.has("meetingUrl") ? active.get("meetingUrl").getAsString():"";
        var ended=new HashSet<String>();
        var history=classrooms.getClassroomHistory(null);
        if(history!=null) for(var value:history) { var entry=value.getAsJsonObject(); if(entry.has("meetingUrl")) ended.add(entry.get("meetingUrl").getAsString()); }
        Map<String,Object> selected=null;
        if(!activeUrl.isBlank()) selected=events.stream().filter(e -> activeUrl.equals(e.get("meetingUrl")) || (string(course,"calendarEventId").equals(e.get("id")) && activeUrl.equals(course.get("meetingUrl")))).findFirst().orElse(null);
        if(selected==null && !string(course,"calendarEventId").isBlank() && (!Boolean.TRUE.equals(course.get("calendarCreated")) || Set.of("PENDING","CREATING","VERIFY_FAILED").contains(string(course,"calendarStatus"))))
            selected=events.stream().filter(e -> string(course,"calendarEventId").equals(e.get("id"))).findFirst().orElse(null);
        if(selected==null) selected=events.stream().filter(e -> map(e.get("request")).containsKey("conferenceData") && !ended.contains(eventMeetingUrl(course,e)) && !(string(course,"calendarEventId").equals(e.get("id")) && "FAILED".equals(course.get("calendarStatus"))))
            .filter(e -> Instant.parse(required(e,"end")).isAfter(now) && !Instant.parse(required(e,"start")).isAfter(now.plusSeconds(900)))
            .min(Comparator.<Map<String,Object>,Integer>comparing(e -> Instant.parse(required(e,"start")).isAfter(now)?1:0)
                .thenComparing(e -> Math.abs(java.time.Duration.between(now,Instant.parse(required(e,"start"))).toSeconds())))
            .orElse(null);
        if(selected==null) {
            if(events.stream().anyMatch(e -> requestId.replace("-","").equals(e.get("id"))))
                throw new GoogleFailure(409,"START_REQUEST_FINISHED","Buổi của lần bấm trước đã kết thúc. Tải lại danh sách để bắt đầu buổi mới.");
            return schedule(email,id,requestId,now.toString(),now.plusSeconds(5400).toString());
        }
        course.put("admissionMode","CALENDAR"); course.put("calendarEventId",selected.get("id"));
        var managed=new HashSet<String>();
        for(var attendee:maps(map(selected.get("request")).get("attendees"))) managed.add(string(attendee,"email"));
        if(selected.get("managedEmails") instanceof List<?> list) for(var value:list) managed.add(value.toString());
        course.put("calendarManagedEmails",managed);
        store.saveCourse(subject,course);
        return syncCalendar(subject,course,connections.access(email));
    }
    private static String eventMeetingUrl(Map<String,Object> course,Map<String,Object> event) {
        String url=string(event,"meetingUrl");
        return url.isBlank() && string(course,"calendarEventId").equals(event.get("id")) ? string(course,"meetingUrl") : url;
    }
    private void requireReady(Map<String,Object> course) {
        if("CALENDAR".equals(course.get("admissionMode"))) {
            if(!"READY".equals(course.get("calendarStatus")) || string(course,"meetingUrl").isBlank() || !(course.get("warnings") instanceof List<?> warnings) || !warnings.isEmpty())
                throw new GoogleFailure(409,"CALENDAR_NOT_READY","Phòng Calendar chưa sẵn sàng. Bấm Đồng bộ và kiểm tra thông báo.");
            var event=maps(course.get("events")).stream().filter(e -> string(course,"calendarEventId").equals(e.get("id"))).findFirst().orElseThrow();
            if(!Instant.parse(required(event,"end")).isAfter(Instant.now()))
                throw new GoogleFailure(409,"CALENDAR_ENDED","Buổi Calendar này đã kết thúc. Chuẩn bị phòng cho buổi mới.");
            return;
        }
        if(string(course,"meetingUrl").isBlank() || !Set.of("RESTRICTED","TRUSTED").contains(string(course,"accessType")) || maps(course.get("students")).stream().anyMatch(s -> Boolean.TRUE.equals(s.get("meetAllowed")) && !"GRANTED".equals(s.get("meetStatus")))
                || !(course.get("warnings") instanceof List<?> warnings) || !warnings.isEmpty())
            throw new GoogleFailure(409,"CLASS_NOT_READY","Lớp chưa sẵn sàng. Đồng bộ và xử lý các thông báo trước khi bắt đầu hoặc gửi lịch.");
    }
    private Map<String,Object> awaitingActivation(String subject,Map<String,Object> course,String detail,String token) {
        var warnings=new ArrayList<String>();
        warnings.add("Lớp đã được tạo nhưng Google chưa xác nhận kích hoạt. Bấm Mở Classroom để chấp nhận lớp, sau đó trở về HocLuc bấm Đồng bộ. Chưa gửi lời mời học sinh.");
        if(detail!=null) warnings.add(detail);
        course.put("classroomWarnings",warnings); store.saveCourse(subject,course); return syncMeet(subject,course,token);
    }
    private void migrateMeetAccess(Map<String,Object> course,List<Map<String,Object>> students) {
        var intended=course.get("intendedEmails") instanceof List<?> list ? list : List.of();
        for(var row:students) if(!row.containsKey("meetAllowed")) row.put("meetAllowed",intended.contains(row.get("email"))
            || !string(row,"invitationId").isBlank() || Set.of("INVITED","INVITE_FAILED","NOT_INVITED").contains(string(row,"classroomStatus")));
    }
    private List<Map<String,Object>> pages(String url,String field,String token) {
        var result=new ArrayList<Map<String,Object>>(); Set<String> seen=new HashSet<>(); String page="";
        do {
            if(!seen.add(page)) throw new GoogleFailure(502,"GOOGLE_PAGINATION","Không đọc đủ danh sách Google. Thử đồng bộ lại.");
            var response=google.call("GET",url+(page.isBlank()?"":(url.contains("?")?"&":"?")+"pageToken="+encode(page)),token,null);
            result.addAll(maps(response.get(field))); page=string(response,"nextPageToken");
        } while(!page.isBlank());
        return result;
    }
    static List<String> emails(List<String> values) {
        if(values==null || values.size()>50) throw new GoogleFailure(400,"INVALID_EMAILS","Mỗi lần mời tối đa 50 email.");
        return values.stream().map(GoogleConnectionService::normalizeEmail).distinct().toList();
    }
    private static void requireId(String id) {
        if(id==null || !id.matches("[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"))
            throw new GoogleFailure(400,"INVALID_REQUEST","Mã thao tác không hợp lệ.");
    }
    private static String encode(String text) { return URLEncoder.encode(text,StandardCharsets.UTF_8); }
    private static boolean sameTime(Instant expected,Map<String,Object> time) {
        try { return expected.truncatedTo(java.time.temporal.ChronoUnit.SECONDS).equals(java.time.OffsetDateTime.parse(string(time,"dateTime")).toInstant().truncatedTo(java.time.temporal.ChronoUnit.SECONDS)); }
        catch(Exception e) { return false; }
    }
    private static String profileEmail(Map<String,Object> student) { return string(map(student.get("profile")),"emailAddress").toLowerCase(Locale.ROOT); }
    private static String required(Map<String,Object> value,String key) {
        String result=string(value,key); if(result.isBlank()) throw new GoogleFailure(502,"GOOGLE_RESPONSE","Google chưa trả đủ thông tin. Đồng bộ lại để kiểm tra."); return result;
    }
    @SuppressWarnings("unchecked") private static Map<String,Object> map(Object value) { return value instanceof Map ? (Map<String,Object>)value : Map.of(); }
    @SuppressWarnings("unchecked") private static List<Map<String,Object>> maps(Object value) { return value instanceof List ? (List<Map<String,Object>>)value : List.of(); }
    private static List<Map<String,Object>> students(Map<String,Object> course) { return new ArrayList<>(maps(course.get("students"))); }
}
