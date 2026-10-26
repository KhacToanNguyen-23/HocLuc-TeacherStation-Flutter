package vn.teaching.integrations;

import org.springframework.stereotype.Service;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.*;
import java.util.regex.Pattern;
import static vn.teaching.integrations.GoogleConnectionService.*;

/** Orchestrates independent providers. Classroom courses are mapped to app-created Meet spaces. */
@Service
public class GoogleClassService {
    private static final String CLASSROOM="https://classroom.googleapis.com/v1/";
    private static final String MEET="https://meet.googleapis.com/v2/";
    private static final Pattern COURSE_TITLE_WHITESPACE = Pattern.compile(
        "[\\x{0009}-\\x{000D}\\x{0020}\\x{0085}\\x{00A0}\\x{1680}\\x{2000}-\\x{200A}\\x{2028}\\x{2029}\\x{202F}\\x{205F}\\x{3000}\\x{FEFF}]+"
    );
    private final GoogleConnectionService connections;
    private final GoogleGateway google;
    private final GoogleStore store;
    private final vn.teaching.modules.classroom.service.ClassroomService classrooms;
    private final GoogleScheduleService scheduleService;
    public GoogleClassService(GoogleConnectionService connections, GoogleGateway google, GoogleStore store, vn.teaching.modules.classroom.service.ClassroomService classrooms, GoogleScheduleService scheduleService) {
        this.connections=connections; this.google=google; this.store=store;
        this.classrooms=classrooms; this.scheduleService=scheduleService;
    }
    public synchronized List<Map<String,Object>> list(String email) {
        String subject=connections.subject(email);
        var courses=store.courses(subject);
        var remoteCourses=courses.stream().filter(course -> !string(course,"courseId").isBlank()).toList();
        if(remoteCourses.isEmpty()) return courses;
        try {
            String token=connections.access(email);
            var remote=pages(CLASSROOM+"courses?teacherId=me","courses",token);
            var byId=new HashMap<String,Map<String,Object>>();
            for(var item:remote) if(!string(item,"id").isBlank()) byId.put(string(item,"id"),item);
            for(var course:remoteCourses) {
                var classroom=byId.get(string(course,"courseId"));
                if(classroom==null) {
                    try {
                        classroom=google.call("GET",CLASSROOM+"courses/"+encode(string(course,"courseId")),token,null);
                    } catch(GoogleFailure failure) {
                        if("GOOGLE_404".equals(failure.code)) {
                            store.deleteCourse(subject,string(course,"id"));
                            continue;
                        }
                        course.put("classroomStateSyncError",failure.getMessage());
                        store.saveCourse(subject,course);
                        continue;
                    }
                }
                if(string(classroom,"courseState").isBlank()) {
                    course.put("classroomStateSyncError","Không đồng bộ được trạng thái lớp từ Google Classroom. Thử tải lại.");
                } else {
                    course.put("classroomState",string(classroom,"courseState"));
                    course.remove("classroomStateSyncError");
                }
                store.saveCourse(subject,course);
            }
        } catch(GoogleFailure failure) {
            for(var course:remoteCourses) {
                course.put("classroomStateSyncError",failure.getMessage());
                store.saveCourse(subject,course);
            }
        }
        return store.courses(subject);
    }
    public synchronized Map<String,Object> archive(String email,String id) {
        return changeCourseState(email,id,"ACTIVE","ARCHIVED");
    }
    public synchronized Map<String,Object> restore(String email,String id) {
        return changeCourseState(email,id,"ARCHIVED","ACTIVE");
    }
    private Map<String,Object> changeCourseState(String email,String id,String expected,String target) {
        String subject=connections.subject(email);
        var course=store.course(subject,id);
        String courseId=string(course,"courseId");
        if(courseId.isBlank()) throw new GoogleFailure(409,"CLASSROOM_NOT_CREATED","Lá»›p chÆ°a Ä‘Æ°á»£c táº¡o trÃªn Google Classroom.");
        String token=connections.access(email),url=CLASSROOM+"courses/"+encode(courseId);
        try {
            var current=google.call("GET",url,token,null);
            String state=required(current,"courseState");
            course.put("classroomState",state);
            course.remove("classroomStateSyncError");
            store.saveCourse(subject,course);
            if(target.equals(state)) return course;
            if(!expected.equals(state)) {
                String code="PROVISIONED".equals(state)?"CLASSROOM_NOT_ACTIVE":"CLASSROOM_STATE_CHANGED";
                String message="PROVISIONED".equals(state)
                    ? "Mở Google Classroom và kích hoạt lớp trước khi lưu trữ."
                    : "Trạng thái lớp trên Google vừa thay đổi. Tải lại danh sách rồi thử lại.";
                throw new GoogleFailure(409,code,message);
            }
            google.call("PATCH",url+"?updateMask=courseState",token,Map.of("courseState",target));
            var confirmed=google.call("GET",url,token,null);
            if(!target.equals(string(confirmed,"courseState")))
                throw new GoogleFailure(409,"CLASSROOM_STATE_UNVERIFIED","Google chưa xác nhận trạng thái mới. Tải lại danh sách rồi thử lại.");
            course.put("classroomState",target);
            course.remove("classroomStateSyncError");
            store.saveCourse(subject,course);
            return course;
        } catch(GoogleFailure failure) {
            course.put("classroomStateSyncError",failure.getMessage());
            store.saveCourse(subject,course);
            throw failure;
        }
    }
    public synchronized Map<String,Object> create(String email,String requestId,String title,String description,List<String> emails) {
        requireId(requestId); title=title==null?"":title.trim();
        if(title.isEmpty() || title.length()>200 || (description!=null && description.length()>2000))
            throw new GoogleFailure(400,"INVALID_CLASS","Tên lớp từ 1–200 ký tự, mô tả tối đa 2000 ký tự.");
        var normalized=emails(emails); String subject=connections.subject(email);
        Map<String,Object> course=store.courses(subject).stream().filter(c -> requestId.equals(c.get("id"))).findFirst().orElse(null);
        if (course == null) {
            String titleKey = normalizedTitle(title);
            boolean duplicate = store.courses(subject).stream()
                .anyMatch(existing -> titleKey.equals(normalizedTitle(existing.get("title"))));
            if (duplicate) {
                throw new GoogleFailure(409,"DUPLICATE_CLASS_TITLE","Tên lớp này đã tồn tại trong HocLuc. Hãy chọn lớp hiện có hoặc đổi tên.");
            }
        }
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
    public synchronized Map<String,Object> update(String email,String id,String title,String description) {
        title=title==null?"":title.trim();
        description=description==null?"":description;
        if(title.isEmpty() || title.length()>200 || description.length()>2000)
            throw new GoogleFailure(400,"INVALID_CLASS","Tên lớp cần từ 1–200 ký tự; mô tả tối đa 2000 ký tự.");
        String subject=connections.subject(email);
        var course=store.course(subject,id);
        String key=normalizedTitle(title);
        boolean titleChanged=!key.equals(normalizedTitle(course.get("title")));
        boolean duplicate=titleChanged && store.courses(subject).stream().anyMatch(other -> !id.equals(other.get("id")) && key.equals(normalizedTitle(other.get("title"))));
        if(duplicate) throw new GoogleFailure(409,"DUPLICATE_CLASS_TITLE","Tên lớp này đã tồn tại trong HocLuc.");
        if(!string(course,"courseId").isBlank()) {
            var changed=google.call("PATCH",CLASSROOM+"courses/"+encode(string(course,"courseId"))+"?updateMask=name,description",connections.access(email),Map.of("name",title,"description",description));
            course.put("classroomState",changed.getOrDefault("courseState",course.get("classroomState")));
            if(changed.get("alternateLink") instanceof String url) course.put("classroomUrl",url);
        }
        course.put("title",title); course.put("description",description); store.saveCourse(subject,course);
        return course;
    }
    public synchronized void delete(String email,String id) {
        String subject=connections.subject(email);
        var course=store.course(subject,id);
        String googleCourseId=string(course,"courseId");
        if(!googleCourseId.isBlank()) {
            String token=connections.access(email);
            try {
                var remote=google.call("GET",CLASSROOM+"courses/"+encode(googleCourseId),token,null);
                String state=required(remote,"courseState");
                course.put("classroomState",state);
                course.remove("classroomStateSyncError");
                store.saveCourse(subject,course);
                if(!"ARCHIVED".equals(state))
                    throw new GoogleFailure(409,"CLASSROOM_NOT_ARCHIVED","Lưu trữ lớp trên Google Classroom trước khi xóa vĩnh viễn.");
                google.call("DELETE",CLASSROOM+"courses/"+encode(googleCourseId),token,null);
            } catch(GoogleFailure failure) {
                // A lost delete response can leave Classroom already deleted; let retry finish local cleanup.
                if(!"GOOGLE_404".equals(failure.code)) {
                    course.put("classroomStateSyncError",failure.getMessage());
                    store.saveCourse(subject,course);
                    throw failure;
                }
            }
        }
        store.deleteCourse(subject,id);
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
        boolean classroomSyncCompleted=false;
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
            classroomSyncCompleted=true;
        } catch(GoogleFailure failure) { classroomWarnings.add(failure.getMessage()); }
        if(classroomSyncCompleted) course.put("classroomSyncedAt",Instant.now().toString());
        course.put("classroomWarnings",classroomWarnings); course.put("students",students); store.saveCourse(subject,course);
        return syncMeet(subject,course,token);
    }
    private Map<String,Object> syncMeet(String subject,Map<String,Object> course,String token) {
        if("CALENDAR".equals(course.get("admissionMode"))) return scheduleService.syncCalendar(subject,course,token);
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
        return scheduleService.schedule(email, id, requestId, start, end);
    }
    public Map<String,Object> prepare(String email,String id) {
        var course=sync(email,id); scheduleService.requireReady(course); return course;
    }
    public synchronized Map<String,Object> start(String email,String id,String requestId) {
        return scheduleService.start(email, id, requestId);
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
    private static String normalizedTitle(Object value) {
        if (!(value instanceof String title)) return "";
        return COURSE_TITLE_WHITESPACE.matcher(title).replaceAll(" ").trim().toLowerCase(Locale.ROOT);
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
