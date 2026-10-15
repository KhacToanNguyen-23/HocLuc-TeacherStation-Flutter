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
    private final GoogleConnectionService connections;
    private final GoogleGateway google;
    private final GoogleStore store;
    public GoogleClassService(GoogleConnectionService connections, GoogleGateway google, GoogleStore store) {
        this.connections=connections; this.google=google; this.store=store;
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
                if(!e.code.equals("GOOGLE_409")) throw e;
                remote=google.call("GET",CLASSROOM+"courses/"+encode(alias),token,null);
            }
            course.put("courseId",required(remote,"id")); course.put("classroomUrl",string(remote,"alternateLink"));
            course.put("classroomState",remote.getOrDefault("courseState","PROVISIONED"));
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
        course.put("students",students); store.saveCourse(subject,course);
        if(!"ACTIVE".equals(course.get("classroomState"))) {
            try {
                var active=google.call("PATCH",CLASSROOM+"courses/"+encode(required(course,"courseId"))+"?updateMask=courseState",token,Map.of("courseState","ACTIVE"));
                course.put("classroomState",required(active,"courseState"));
                store.saveCourse(subject,course);
                if(!"ACTIVE".equals(course.get("classroomState"))) return awaitingActivation(subject,course,null);
            } catch(GoogleFailure e) { return awaitingActivation(subject,course,e.getMessage()); }
        }
        return inviteAndSync(email,course,normalized);
    }
    public synchronized Map<String,Object> invite(String email,String id,List<String> requested) {
        var course=store.course(connections.subject(email),id);
        if(course.containsKey("classroomState") && !"ACTIVE".equals(course.get("classroomState")))
            throw new GoogleFailure(409,"CLASSROOM_NOT_ACTIVE","Lớp chưa kích hoạt. Mở Classroom để chấp nhận lớp rồi bấm Đồng bộ trước khi mời thêm học sinh.");
        return inviteAndSync(email,course,emails(requested));
    }
    private Map<String,Object> inviteAndSync(String email,Map<String,Object> course,List<String> requested) {
        String subject=connections.subject(email),token=connections.access(email);
        var students=students(course); var warnings=new ArrayList<String>();
        // Read current roster first, including invitations accepted outside HocLuc.
        var roster=pages(CLASSROOM+"courses/"+encode(required(course,"courseId"))+"/students", "students",token);
        for(String studentEmail:requested) {
            var student=students.stream().filter(s -> studentEmail.equals(s.get("email"))).findFirst().orElse(null);
            if(student==null) { student=new LinkedHashMap<>(); student.put("email",studentEmail); student.put("name",studentEmail); student.put("meetStatus","NOT_GRANTED"); students.add(student); }
            boolean joined=roster.stream().anyMatch(r -> studentEmail.equals(profileEmail(r)));
            if(joined || "INVITED".equals(student.get("classroomStatus"))) continue;
            try {
                var invitation=google.call("POST",CLASSROOM+"invitations",token,Map.of("courseId",course.get("courseId"),"userId",studentEmail,"role","STUDENT"));
                student.put("invitationId",required(invitation,"id")); student.put("googleUserId",string(invitation,"userId")); student.put("classroomStatus","INVITED"); student.remove("error");
            } catch(GoogleFailure e) {
                // Existing invite is not proof of membership; sync resolves the actual status.
                if(e.code.equals("GOOGLE_409")) student.put("classroomStatus","INVITED");
                else { student.put("classroomStatus","INVITE_FAILED"); student.put("error",e.getMessage()); warnings.add(studentEmail+": "+e.getMessage()); }
            }
            course.put("students",students); store.saveCourse(subject,course);
        }
        course.put("students",students); course.put("warnings",warnings); store.saveCourse(subject,course);
        return sync(email, string(course,"id"));
    }
    public synchronized Map<String,Object> sync(String email,String id) {
        String subject=connections.subject(email), token=connections.access(email); var course=store.course(subject,id);
        if(string(course,"courseId").isBlank()) throw new GoogleFailure(409,"CREATE_INCOMPLETE","Lớp chưa tạo xong. Thử lại biểu mẫu tạo lớp.");
        if(course.containsKey("classroomState") && !"ACTIVE".equals(course.get("classroomState"))) {
            var remote=google.call("GET",CLASSROOM+"courses/"+encode(string(course,"courseId")),token,null);
            course.put("classroomState",required(remote,"courseState")); store.saveCourse(subject,course);
            if(!"ACTIVE".equals(course.get("classroomState"))) return awaitingActivation(subject,course,null);
            // Invitations were deliberately deferred until Google confirmed activation.
            var intended=students(course).stream().filter(s -> "NOT_INVITED".equals(s.get("classroomStatus"))).map(s -> string(s,"email")).toList();
            return inviteAndSync(email,course,intended);
        }
        var roster=pages(CLASSROOM+"courses/"+encode(string(course,"courseId"))+"/students","students",token);
        var invitations=pages(CLASSROOM+"invitations?courseId="+encode(string(course,"courseId")),"invitations",token);
        var students=students(course); var warnings=new ArrayList<String>();
        Set<String> joined=new HashSet<>(); Set<String> pendingIds=new HashSet<>();
        for(var invitation:invitations) if("STUDENT".equals(invitation.get("role"))) pendingIds.add(string(invitation,"id"));
        for(var remote:roster) {
            String studentEmail=profileEmail(remote); if(studentEmail.isBlank()) throw new GoogleFailure(502,"ROSTER_EMAIL_MISSING","Google không trả email thành viên. Kiểm tra quyền đọc email và đồng bộ lại.");
            joined.add(studentEmail);
            String userId=string(remote,"userId");
            var student=students.stream().filter(s -> studentEmail.equals(s.get("email")) || (!userId.isBlank() && userId.equals(s.get("googleUserId")))).findFirst().orElse(null);
            if(student==null) { student=new LinkedHashMap<>(); student.put("email",studentEmail); student.put("meetStatus","NOT_GRANTED"); students.add(student); }
            var profile=map(remote.get("profile")); var name=map(profile.get("name"));
            student.put("email",studentEmail); student.put("googleUserId",userId);
            student.put("name",name.getOrDefault("fullName",studentEmail)); student.put("classroomStatus","JOINED"); student.remove("error");
        }
        for(var student:students) {
            if(joined.contains(string(student,"email"))) continue;
            String previous=string(student,"classroomStatus");
            if(previous.equals("JOINED")) student.put("classroomStatus","LEFT");
            else if(previous.equals("INVITED") && !string(student,"invitationId").isBlank() && !pendingIds.contains(string(student,"invitationId"))) student.put("classroomStatus","INVITATION_CLOSED");
        }
        course.put("students",students); store.saveCourse(subject,course);
        try {
            if(string(course,"spaceName").isBlank()) {
                if(Boolean.TRUE.equals(course.get("meetCreationUncertain"))) throw new GoogleFailure(409,"MEET_UNCERTAIN","Chưa xác định được kết quả tạo Meet. Không tự tạo lại để tránh phòng trùng; liên hệ người cài đặt kiểm tra.");
                Map<String,Object> space;
                try { space=google.call("POST",MEET+"spaces",token,Map.of("config",Map.of("accessType","TRUSTED"))); }
                catch(GoogleFailure e) {
                    if(e.code.equals("GOOGLE_NETWORK") || e.code.matches("GOOGLE_5[0-9][0-9]")) { course.put("meetCreationUncertain",true); store.saveCourse(subject,course); }
                    throw e;
                }
                course.put("spaceName",required(space,"name")); course.put("meetingUrl",required(space,"meetingUri"));
                course.put("accessType",string(map(space.get("config")),"accessType")); store.saveCourse(subject,course);
            }
            String space=required(course,"spaceName");
            // Read all pages before mutating any membership. Never revoke on a partial roster.
            var remoteMembers=pages(MEET+space+"/members","members",token);
            for(var student:students) {
                String studentEmail=string(student,"email");
                var remote=remoteMembers.stream().filter(m -> studentEmail.equalsIgnoreCase(string(m,"email")) || (!string(student,"memberName").isBlank() && student.get("memberName").equals(m.get("name")))).findFirst().orElse(null);
                try {
                    if(joined.contains(studentEmail)) {
                        if(remote==null) {
                            student.put("grantAttempted",true); store.saveCourse(subject,course);
                            remote=google.call("POST",MEET+space+"/members",token,Map.of("email",studentEmail,"role","ROLE_UNSPECIFIED"));
                        }
                        student.put("memberName",required(remote,"name")); student.put("meetStatus","GRANTED"); student.remove("error");
                    } else if(!string(student,"memberName").isBlank() || Boolean.TRUE.equals(student.get("grantAttempted"))) {
                        if(remote!=null) google.call("DELETE",MEET+required(remote,"name"),token,null);
                        student.remove("memberName"); student.remove("grantAttempted"); student.put("meetStatus","NOT_GRANTED"); student.remove("error");
                    }
                } catch(GoogleFailure e) { student.put("meetStatus",joined.contains(studentEmail)?"GRANT_FAILED":"REVOKE_FAILED"); student.put("error",e.getMessage()); warnings.add(studentEmail+": "+e.getMessage()); }
                store.saveCourse(subject,course);
            }
            // Confirm actual access settings rather than assuming requested values were accepted.
            var spaceState=google.call("GET",MEET+space,token,null);
            String access=string(map(spaceState.get("config")),"accessType"); course.put("accessType",access);
            if(!Set.of("TRUSTED","RESTRICTED").contains(access)) warnings.add("Phòng chưa có cấu hình giới hạn phù hợp. Kiểm tra quyền truy cập Meet.");
        } catch(GoogleFailure e) { warnings.add(e.getMessage()); }
        for(var student:students) if("INVITE_FAILED".equals(student.get("classroomStatus"))) warnings.add(string(student,"email")+": chưa mời được vào Classroom.");
        course.put("warnings",warnings); course.put("syncedAt",Instant.now().toString());
        store.saveCourse(subject,course); return course;
    }
    public synchronized Map<String,Object> schedule(String email,String id,String requestId,String start,String end) {
        requireId(requestId); Instant from,to;
        try { from=Instant.parse(start); to=Instant.parse(end); } catch(Exception e) { throw new GoogleFailure(400,"INVALID_TIME","Thời gian học không hợp lệ."); }
        if(!to.isAfter(from) || from.isBefore(Instant.now().minusSeconds(60)) || to.isAfter(from.plusSeconds(86400)))
            throw new GoogleFailure(400,"INVALID_TIME","Chọn buổi học trong tương lai, kết thúc sau bắt đầu và không quá 24 giờ.");
        var course=sync(email,id); requireReady(course);
        String subject=connections.subject(email), token=connections.access(email);
        String eventId=requestId.replace("-","");
        var events=new ArrayList<>(maps(course.get("events")));
        if(events.stream().anyMatch(e -> eventId.equals(e.get("id")))) return course;
        var attendees=students(course).stream().filter(s -> "JOINED".equals(s.get("classroomStatus"))).map(s -> Map.of("email",s.get("email"))).toList();
        if(attendees.isEmpty()) throw new GoogleFailure(409,"NO_STUDENTS","Chưa có học sinh tham gia Classroom để gửi lịch.");
        String link=required(course,"meetingUrl");
        var body=new LinkedHashMap<String,Object>(); body.put("id",eventId); body.put("summary",course.get("title"));
        body.put("start",Map.of("dateTime",from.toString())); body.put("end",Map.of("dateTime",to.toString()));
        body.put("location",link); body.put("description","Vào học bằng đúng tài khoản đã tham gia lớp.\nGoogle Meet: "+link);
        body.put("attendees",attendees); body.put("guestsCanInviteOthers",false); body.put("guestsCanSeeOtherGuests",false);
        Map<String,Object> event;
        try { event=google.call("POST","https://www.googleapis.com/calendar/v3/calendars/primary/events?sendUpdates=all",token,body); }
        catch(GoogleFailure e) {
            if(!e.code.equals("GOOGLE_409")) throw e;
            event=google.call("GET","https://www.googleapis.com/calendar/v3/calendars/primary/events/"+eventId,token,null);
            if(!link.equals(string(event,"location")) || !sameTime(from,map(event.get("start"))) || !sameTime(to,map(event.get("end"))))
                throw new GoogleFailure(409,"CALENDAR_RETRY_CHANGED","Yêu cầu này đã tạo lịch với thông tin khác. Kiểm tra Google Calendar trước khi gửi lịch mới.");
        }
        events.add(Map.of("id",required(event,"id"),"start",from.toString(),"end",to.toString(),"url",string(event,"htmlLink"),"inviteeCount",attendees.size()));
        course.put("events",events); store.saveCourse(subject,course); return course;
    }
    public Map<String,Object> prepare(String email,String id) {
        var course=sync(email,id); requireReady(course); return course;
    }
    private void requireReady(Map<String,Object> course) {
        if(string(course,"meetingUrl").isBlank() || !maps(course.get("students")).stream().allMatch(s -> !"REVOKE_FAILED".equals(s.get("meetStatus")))
                || !(course.get("warnings") instanceof List<?> warnings) || !warnings.isEmpty())
            throw new GoogleFailure(409,"CLASS_NOT_READY","Lớp chưa sẵn sàng. Đồng bộ và xử lý các thông báo trước khi bắt đầu hoặc gửi lịch.");
    }
    private Map<String,Object> awaitingActivation(String subject,Map<String,Object> course,String detail) {
        var warnings=new ArrayList<String>();
        warnings.add("Lớp đã được tạo nhưng Google chưa xác nhận kích hoạt. Bấm Mở Classroom để chấp nhận lớp, sau đó trở về HocLuc bấm Đồng bộ. Chưa gửi lời mời học sinh.");
        if(detail!=null) warnings.add(detail);
        course.put("warnings",warnings); store.saveCourse(subject,course); return course;
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
        try { return expected.equals(java.time.OffsetDateTime.parse(string(time,"dateTime")).toInstant()); }
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
