package vn.teaching.integrations;

import org.junit.jupiter.api.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.web.servlet.MockMvc;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(properties={"spring.datasource.url=jdbc:h2:mem:google-tests;MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1",
    "app.integrations.google.client-id=desktop-client", "app.integrations.google.encryption-key=AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="})
@AutoConfigureMockMvc
class GoogleIntegrationTest {
    @Autowired GoogleConnectionService connections;
    @Autowired GoogleClassService classes;
    @Autowired GoogleStore store;
    @Autowired JdbcTemplate jdbc;
    @Autowired MockMvc mvc;
    @Autowired String companionToken;
    @MockBean GoogleGateway google;
    @MockBean vn.teaching.service.ClassroomService classrooms;
    static final String EMAIL="teacher@example.com", SUBJECT="teacher-sub", COURSE="11111111-1111-4111-8111-111111111111";
    static final String C="https://classroom.googleapis.com/v1/", M="https://meet.googleapis.com/v2/";
    @BeforeEach void setup() {
        jdbc.update("DELETE FROM exam_platform.google_courses"); jdbc.update("DELETE FROM exam_platform.google_connections");
        reset(google);
        when(classrooms.getActiveClassroom()).thenReturn(new com.google.gson.JsonObject());
        when(classrooms.getClassroomHistory(null)).thenReturn(new com.google.gson.JsonArray());
        var meetingMembers=new LinkedHashMap<String,Map<String,Object>>();
        when(google.call(eq("GET"),eq(M+"spaces/test/members"),anyString(),isNull())).thenAnswer(call -> Map.of("members",new ArrayList<>(meetingMembers.values())));
        when(google.call(eq("GET"),eq(M+"spaces/test"),anyString(),isNull())).thenReturn(Map.of("config",Map.of("accessType","RESTRICTED")));
        when(google.call(eq("POST"),eq(M+"spaces"),anyString(),any())).thenReturn(Map.of("name","spaces/test","meetingUri","https://meet.google.com/abc-defg-hij","config",Map.of("accessType","RESTRICTED")));
        when(google.call(eq("POST"),eq(M+"spaces/test/members"),anyString(),any())).thenAnswer(call -> {
            Map<?,?> body=call.getArgument(3); String address=body.get("email").toString();
            var member=Map.<String,Object>of("name","spaces/test/members/"+address.split("@")[0],"email",address);
            meetingMembers.put(address,member); return member;
        });
        when(google.call(eq("DELETE"),startsWith(M+"spaces/test/members/"),anyString(),isNull())).thenAnswer(call -> {
            String resource=call.getArgument(1); meetingMembers.values().removeIf(member -> resource.equals(M+member.get("name"))); return Map.of();
        });

        store.saveConnection(SUBJECT,EMAIL,new LinkedHashMap<>(Map.of("access_token","private-access","refresh_token","private-refresh","expiresAt",System.currentTimeMillis()+3600000)));
    }
    private Map<String,Object> course() {
        var result=new LinkedHashMap<String,Object>(); result.put("id",COURSE); result.put("title","Toán 12A"); result.put("courseId","google-course");
        result.put("spaceName","spaces/test"); result.put("meetingUrl","https://meet.google.com/abc-defg-hij"); result.put("students",new ArrayList<>());
        store.saveCourse(SUBJECT,result); return result;
    }
    private void roster(List<Map<String,Object>> students) {
        when(google.call(eq("GET"),eq(C+"courses/google-course/students"),anyString(),isNull())).thenReturn(Map.of("students",students));
        when(google.call(eq("GET"),eq(C+"invitations?courseId=google-course"),anyString(),isNull())).thenReturn(Map.of());
    }
    private Map<String,Object> student(String email) { return Map.of("profile",Map.of("emailAddress",email,"name",Map.of("fullName","Student"))); }
    private void allowStudent(String address) {
        var saved=store.course(SUBJECT,COURSE);
        saved.put("students",new ArrayList<>(List.of(new LinkedHashMap<>(Map.of("email",address,"meetAllowed",true,"classroomStatus","INVITED")))));
        store.saveCourse(SUBJECT,saved);
    }
    @Test void pendingClassroomInvitationDoesNotBlockReadyMeetAndSyncIsIdempotent() {
        course(); roster(List.of()); allowStudent("pending@example.com");
        var result=classes.prepare(EMAIL,COURSE);
        assertTrue(result.toString().contains("GRANTED"));
        classes.prepare(EMAIL,COURSE);
        verify(google,times(1)).call(eq("POST"),eq(M+"spaces/test/members"),anyString(),any());
    }
    @Test void classroomCreateFailureDoesNotBlockCalendarPreparation() {
        when(google.call(eq("POST"),eq(C+"courses"),anyString(),any())).thenThrow(new GoogleFailure(502,"GOOGLE_403","Classroom unavailable"));
        var result=classes.create(EMAIL,COURSE,"Test","",List.of("pending@example.com"));
        assertEquals("NOT_PREPARED",result.get("calendarStatus"));
        assertFalse(((List<?>)result.get("classroomWarnings")).isEmpty());
        calendarServer("success"); var time=calendarTimes();
        classes.schedule(EMAIL,COURSE,UUID.randomUUID().toString(),time[0],time[1]);
        assertEquals("READY",classes.prepare(EMAIL,COURSE).get("calendarStatus"));
    }
    @Test void postResponseWithoutReadbackIsNotAGrant() {
        course(); roster(List.of()); allowStudent("pending@example.com");
        when(google.call(eq("POST"),eq(M+"spaces/test/members"),anyString(),any())).thenReturn(Map.of("name","spaces/test/members/pending","email","pending@example.com"));
        var result=classes.sync(EMAIL,COURSE);
        assertTrue(result.toString().contains("GRANT_FAILED"));
        assertThrows(GoogleFailure.class,()->classes.prepare(EMAIL,COURSE));
    }
    @Test void lostCreateResponseIsRecoveredByReadingActualMembership() {
        course(); roster(List.of()); allowStudent("pending@example.com");
        when(google.call(eq("POST"),eq(M+"spaces/test/members"),anyString(),any())).thenThrow(new GoogleFailure(502,"GOOGLE_NETWORK","Timed out"));
        when(google.call(eq("GET"),eq(M+"spaces/test/members"),anyString(),isNull())).thenReturn(Map.of(),Map.of("members",List.of(Map.of("name","spaces/test/members/pending","email","pending@example.com"))));
        assertTrue(classes.prepare(EMAIL,COURSE).toString().contains("GRANTED"));
    }
    @Test void departingClassroomDoesNotRevokeTeacherAllowlist() {
        course(); roster(List.of()); allowStudent("pending@example.com");
        var saved=store.course(SUBJECT,COURSE); ((Map<String,Object>)((List<?>)saved.get("students")).get(0)).put("classroomStatus","JOINED"); store.saveCourse(SUBJECT,saved);
        var result=classes.prepare(EMAIL,COURSE);
        assertTrue(result.toString().contains("LEFT")); assertTrue(result.toString().contains("GRANTED"));
        verify(google,never()).call(eq("DELETE"),anyString(),anyString(),any());
    }
    @Test void explicitRevokeIsVerifiedAndCannotBeUndoneByClassroomRoster() {
        course(); roster(List.of(student("pending@example.com"))); allowStudent("pending@example.com");
        classes.prepare(EMAIL,COURSE);
        var result=classes.setMeetAccess(EMAIL,COURSE,"pending@example.com",false);
        assertTrue(result.toString().contains("NOT_GRANTED"));
        classes.sync(EMAIL,COURSE);
        verify(google,times(1)).call(eq("POST"),eq(M+"spaces/test/members"),anyString(),any());
        verify(google,times(1)).call(eq("DELETE"),eq(M+"spaces/test/members/pending"),anyString(),isNull());
    }
    @Test void openAccessIsNeverAcceptedAsAnEmailAllowlist() {
        course(); roster(List.of()); allowStudent("pending@example.com");
        when(google.call(eq("GET"),eq(M+"spaces/test"),anyString(),isNull())).thenReturn(Map.of("config",Map.of("accessType","OPEN")));
        assertThrows(GoogleFailure.class,()->classes.prepare(EMAIL,COURSE));
        verify(google).call(eq("PATCH"),eq(M+"spaces/test?updateMask=config.accessType"),anyString(),eq(Map.of("name","spaces/test","config",Map.of("accessType","RESTRICTED"))));
    }
    @Test void unsupportedRestrictedOnTrustedRoomStillGrantsAndVerifiesMembers() {
        course(); roster(List.of()); allowStudent("pending@example.com");
        when(google.call(eq("GET"),eq(M+"spaces/test"),anyString(),isNull())).thenReturn(Map.of("config",Map.of("accessType","TRUSTED")));
        when(google.call(eq("PATCH"),eq(M+"spaces/test?updateMask=config.accessType"),anyString(),any())).thenThrow(GoogleHttpGateway.preconditionFailure());
        var result=classes.prepare(EMAIL,COURSE);
        assertEquals("TRUSTED",result.get("accessType"));
        assertTrue(result.toString().contains("GRANTED"));
        assertNotNull(result.get("accessNotice"));
        classes.prepare(EMAIL,COURSE);
        verify(google,times(1)).call(eq("PATCH"),eq(M+"spaces/test?updateMask=config.accessType"),anyString(),any());
        verify(google,times(1)).call(eq("POST"),eq(M+"spaces/test/members"),anyString(),any());
    }
    @Test void networkOrPermissionFailureDoesNotTriggerTrustedFallback() {
        course(); roster(List.of()); allowStudent("pending@example.com");
        when(google.call(eq("GET"),eq(M+"spaces/test"),anyString(),isNull())).thenReturn(Map.of("config",Map.of("accessType","TRUSTED")));
        when(google.call(eq("PATCH"),eq(M+"spaces/test?updateMask=config.accessType"),anyString(),any())).thenThrow(new GoogleFailure(502,"GOOGLE_NETWORK","No response"));
        assertThrows(GoogleFailure.class,()->classes.prepare(EMAIL,COURSE));
        verify(google,never()).call(eq("POST"),contains("/members"),anyString(),any());
    }
    @Test void createWithUnsupportedRestrictedRetriesTrustedOnlyAfterExplicitRejection() {
        var saved=course(); saved.remove("spaceName"); saved.remove("meetingUrl"); store.saveCourse(SUBJECT,saved); roster(List.of()); allowStudent("pending@example.com");
        when(google.call(eq("POST"),eq(M+"spaces"),anyString(),eq(Map.of("config",Map.of("accessType","RESTRICTED"))))).thenThrow(GoogleHttpGateway.preconditionFailure());
        when(google.call(eq("GET"),eq(M+"spaces/test"),anyString(),isNull())).thenReturn(Map.of("config",Map.of("accessType","TRUSTED")));
        assertTrue(classes.prepare(EMAIL,COURSE).toString().contains("GRANTED"));
        verify(google,times(1)).call(eq("POST"),eq(M+"spaces"),anyString(),eq(Map.of("config",Map.of("accessType","TRUSTED"))));
    }
    @Test void credentialsAreEncryptedAndNotReturnedByStatus() {
        String raw=jdbc.queryForObject("SELECT credentials FROM exam_platform.google_connections WHERE subject=?",String.class,SUBJECT);
        assertFalse(raw.contains("private-access")); assertFalse(raw.contains("private-refresh"));
        assertEquals("private-access",connections.access(EMAIL));
        assertFalse(connections.status(EMAIL).toString().contains("private-"));
    }
    @Test void creationRetriesReuseCourseAndDoNotDuplicateInvitationsOrRoom() {
        when(google.call(eq("POST"),eq(C+"courses"),anyString(),any())).thenReturn(Map.of("id","google-course","alternateLink","https://classroom.google.com/c/test"));
        when(google.call(eq("PATCH"),eq(C+"courses/google-course?updateMask=courseState"),anyString(),any())).thenReturn(Map.of("courseState","ACTIVE"));
        roster(List.of());
        when(google.call(eq("POST"),eq(C+"invitations"),anyString(),any())).thenReturn(Map.of("id","invitation-1","userId","student-1"));
        when(google.call(eq("GET"),eq(C+"invitations?courseId=google-course"),anyString(),isNull())).thenReturn(Map.of("invitations",List.of(Map.of("id","invitation-1","role","STUDENT"))));
        when(google.call(eq("POST"),eq(M+"spaces"),anyString(),any())).thenReturn(Map.of("name","spaces/test","meetingUri","https://meet.google.com/abc-defg-hij","config",Map.of("accessType","TRUSTED")));
        classes.create(EMAIL,COURSE,"Toán 12A","",List.of("An@Example.com","an@example.com"));
        var result=classes.create(EMAIL,COURSE,"Toán 12A","",List.of("an@example.com"));
        verify(google,times(1)).call(eq("POST"),eq(C+"courses"),anyString(),any());
        verify(google,times(1)).call(eq("POST"),eq(C+"invitations"),anyString(),any());
        verify(google,never()).call(eq("POST"),eq(M+"spaces"),anyString(),any());
        assertEquals(1,((List<?>)result.get("students")).size());
        assertEquals("NOT_PREPARED",result.get("calendarStatus")); assertFalse(result.containsKey("meetingUrl"));
        verify(google).call(eq("POST"),eq(C+"courses"),anyString(),argThat(body -> "PROVISIONED".equals(((Map<?,?>)body).get("courseState"))));
    }
    @Test void activationDeniedDefersInvitationsUntilTeacherAccepts() {
        when(google.call(eq("POST"),eq(C+"courses"),anyString(),any())).thenReturn(Map.of("id","google-course","courseState","PROVISIONED","alternateLink","https://classroom.google.com/c/test"));
        when(google.call(eq("PATCH"),eq(C+"courses/google-course?updateMask=courseState"),anyString(),any())).thenThrow(new GoogleFailure(502,"GOOGLE_403","Activation denied"));
        var result=classes.create(EMAIL,COURSE,"Toán 12A","",List.of("an@example.com"));
        assertEquals("PROVISIONED",result.get("classroomState")); assertTrue(result.get("classroomWarnings").toString().contains("Chưa gửi lời mời"));
        verify(google,never()).call(eq("POST"),eq(C+"invitations"),anyString(),any());
        when(google.call(eq("GET"),eq(C+"courses/google-course"),anyString(),isNull())).thenReturn(Map.of("courseState","ACTIVE"));
        roster(List.of());
        when(google.call(eq("POST"),eq(C+"invitations"),anyString(),any())).thenReturn(Map.of("id","invite-accepted-flow","userId","student-1"));
        when(google.call(eq("POST"),eq(M+"spaces"),anyString(),any())).thenReturn(Map.of("name","spaces/test","meetingUri","https://meet.google.com/abc-defg-hij","config",Map.of("accessType","TRUSTED")));
        var active=classes.sync(EMAIL,COURSE);
        assertEquals("ACTIVE",active.get("classroomState"));
        verify(google).call(eq("POST"),eq(C+"invitations"),anyString(),any());
    }
    @Test void expiredAccessRefreshesOnlyOnBackend() {
        store.saveConnection(SUBJECT,EMAIL,new LinkedHashMap<>(Map.of("access_token","old","refresh_token","private-refresh","expiresAt",0)));
        when(google.token(argThat(f -> "refresh_token".equals(f.get("grant_type"))))).thenReturn(Map.of("access_token","new","expires_in",3600));
        assertEquals("new",connections.access(EMAIL)); assertEquals("new",connections.access(EMAIL)); verify(google,times(1)).token(anyMap());
    }
    @Test void networkFailurePreservesGrantAndAllowsRetryWithoutConsent() {
        store.saveConnection(SUBJECT,EMAIL,new LinkedHashMap<>(Map.of("access_token","old","refresh_token","private-refresh","expiresAt",0)));
        when(google.token(anyMap())).thenThrow(new GoogleFailure(503,"GOOGLE_NETWORK","Mạng tạm lỗi"))
            .thenReturn(Map.of("access_token","recovered","expires_in",3600));
        assertEquals("TEMPORARY_ERROR",connections.status(EMAIL).get("state"));
        assertEquals("private-refresh",store.credentials(SUBJECT).get("refresh_token"));
        assertEquals("CONNECTED",connections.status(EMAIL).get("state"));
        assertEquals("recovered",connections.access(EMAIL));
    }
    @Test void revokedRefreshRequiresConsentAndDoesNotRetryInvalidGrantForever() {
        store.saveConnection(SUBJECT,EMAIL,new LinkedHashMap<>(Map.of("refresh_token","private-refresh","expiresAt",0)));
        when(google.token(anyMap())).thenThrow(new GoogleFailure(401,"RECONNECT_GOOGLE","Đã thu hồi"));
        assertEquals("REAUTH_REQUIRED",connections.status(EMAIL).get("state"));
        assertEquals("REAUTH_REQUIRED",connections.status(EMAIL).get("state"));
        verify(google,times(1)).token(anyMap());
    }
    @Test void expiredAccessReportedByGoogleRefreshesOnceBeforeRequiringConsent() {
        when(google.call(eq("GET"),contains("userinfo"),eq("private-access"),isNull()))
            .thenThrow(new GoogleFailure(401,"GOOGLE_401","Expired access"));
        when(google.token(anyMap())).thenReturn(Map.of("access_token","renewed","expires_in",3600));
        assertEquals("CONNECTED",connections.status(EMAIL).get("state"));
        verify(google,times(1)).token(anyMap());
    }
    @Test void oauthConfigErrorsDoNotAskTeachersToReauthorize() {
        store.saveConnection(SUBJECT,EMAIL,new LinkedHashMap<>(Map.of("refresh_token","r","expiresAt",0)));
        when(google.token(anyMap())).thenThrow(new GoogleFailure(503,"GOOGLE_CLIENT_CONFIG","Cấu hình lỗi"));
        assertEquals("CONFIG_ERROR",connections.status(EMAIL).get("state"));
        assertNotEquals(true,store.credentials(SUBJECT).get("reauthRequired"));
    }
    @Test void tokenErrorsDistinguishRevocationFromServiceAndClientFailures() {
        assertEquals("RECONNECT_GOOGLE",GoogleHttpGateway.tokenFailure(400,"invalid_grant").code);
        assertEquals("GOOGLE_CLIENT_CONFIG",GoogleHttpGateway.tokenFailure(401,"invalid_client").code);
        assertEquals("GOOGLE_RATE_LIMIT",GoogleHttpGateway.tokenFailure(429,"").code);
        assertEquals("GOOGLE_TEMPORARY",GoogleHttpGateway.tokenFailure(503,"").code);
    }
    @Test void disconnectRevokesGrantWhileKeepingClassData() {
        course();
        connections.disconnect(EMAIL);
        verify(google).revoke("private-refresh");
        assertEquals("DISCONNECTED",connections.status(EMAIL).get("state"));
        assertFalse(store.courses(SUBJECT).isEmpty());
    }
    @Test void oauthRejectsWrongProofAndAdoptsVerifiedSelectedAccount() {
        var flow=connections.start(EMAIL);
        assertThrows(GoogleFailure.class,()->connections.poll(flow.get("state").toString(),"wrong"));
        when(google.token(anyMap())).thenReturn(Map.of("access_token","a","refresh_token","r","scope",GoogleConnectionService.SCOPES));
        when(google.call(eq("GET"),contains("userinfo"),eq("a"),isNull())).thenReturn(Map.of("email_verified",true,"email","other@example.com","sub","other-sub"));
        connections.callback(flow.get("state").toString(),"code",null);
        var result=connections.poll(flow.get("state").toString(),flow.get("pollToken").toString());
        assertEquals("other@example.com",result.get("email")); assertTrue(store.subject("other@example.com").isPresent());
    }
    @Test void firstConnectionNeedsNoPriorAppIdentity() {
        assertEquals(false,connections.status("").get("connected"));
        var flow=connections.start("");
        assertFalse(flow.get("authorizationUrl").toString().contains("login_hint"));
        when(google.token(anyMap())).thenReturn(Map.of("access_token","a","refresh_token","r","scope",GoogleConnectionService.SCOPES));
        when(google.call(eq("GET"),contains("userinfo"),eq("a"),isNull())).thenReturn(Map.of("email_verified",true,"email",EMAIL,"sub",SUBJECT));
        connections.callback(flow.get("state").toString(),"code",null);
        assertEquals(EMAIL,connections.poll(flow.get("state").toString(),flow.get("pollToken").toString()).get("email"));
    }
    @Test void savedConnectionOnlyForcesConsentOnExplicitRepair() {
        assertFalse(connections.start(EMAIL).get("authorizationUrl").toString().contains("prompt=consent"));
        assertTrue(connections.start(EMAIL,true).get("authorizationUrl").toString().contains("prompt=consent"));
    }
    @Test void localOAuthSetupDoesNotRequirePriorTeacherEmail() throws Exception {
        mvc.perform(get("/api/integrations/google/status").header("X-Companion-Token",companionToken))
            .andExpect(status().isOk()).andExpect(jsonPath("$.configured").value(true)).andExpect(jsonPath("$.connected").value(false));
        mvc.perform(post("/api/integrations/google/connect").header("X-Companion-Token",companionToken)
            .contentType("application/json").content("{\"email\":\"\"}"))
            .andExpect(status().isOk()).andExpect(jsonPath("$.authorizationUrl").exists());
        mvc.perform(post("/api/integrations/google/connect").contentType("application/json").content("{\"email\":\"\"}"))
            .andExpect(status().isUnauthorized());
    }
    @Test void unverifiedIdentityCannotBecomeAppAccount() {
        var flow=connections.start("");
        when(google.token(anyMap())).thenReturn(Map.of("access_token","a","refresh_token","r","scope",GoogleConnectionService.SCOPES));
        when(google.call(eq("GET"),contains("userinfo"),eq("a"),isNull())).thenReturn(Map.of("email_verified",false,"email","unverified@example.com","sub","unverified"));
        connections.callback(flow.get("state").toString(),"code",null);
        assertThrows(GoogleFailure.class,()->connections.poll(flow.get("state").toString(),flow.get("pollToken").toString()));
        assertTrue(store.subject("unverified@example.com").isEmpty());
    }
    @Test void oauthCompletionIsOneTimeAndRequiresAllScopes() {
        var flow=connections.start(EMAIL);
        when(google.token(anyMap())).thenReturn(Map.of("access_token","a","refresh_token","r","scope",GoogleConnectionService.SCOPES));
        when(google.call(eq("GET"),contains("userinfo"),eq("a"),isNull())).thenReturn(Map.of("email_verified",true,"email",EMAIL,"sub",SUBJECT));
        connections.callback(flow.get("state").toString(),"code",null);
        assertEquals("COMPLETE",connections.poll(flow.get("state").toString(),flow.get("pollToken").toString()).get("status"));
        assertThrows(GoogleFailure.class,()->connections.poll(flow.get("state").toString(),flow.get("pollToken").toString()));
        assertEquals("a",connections.access(EMAIL));
    }
    @Test void partialConsentDoesNotOverwriteConnection() {
        var flow=connections.start(EMAIL);
        when(google.token(anyMap())).thenReturn(Map.of("access_token","a","refresh_token","r","scope","openid email profile"));
        when(google.call(eq("GET"),contains("userinfo"),eq("a"),isNull())).thenReturn(Map.of("email_verified",true,"email",EMAIL,"sub",SUBJECT));
        connections.callback(flow.get("state").toString(),"code",null);
        assertThrows(GoogleFailure.class,()->connections.poll(flow.get("state").toString(),flow.get("pollToken").toString()));
        assertEquals("private-access",connections.access(EMAIL));
    }
    @Test void pendingClassroomStudentGetsMeetAccessButImportedRosterDoesNot() {
        var course=course(); course.put("students",List.of(new LinkedHashMap<>(Map.of("email","pending@example.com","classroomStatus","INVITED","meetStatus","NOT_GRANTED","meetAllowed",true)))); store.saveCourse(SUBJECT,course);
        roster(List.of(student("joined@example.com")));
        var result=classes.sync(EMAIL,COURSE);
        assertTrue(result.toString().contains("GRANTED"));
        verify(google).call(eq("POST"),contains("/members"),anyString(),eq(Map.of("email","pending@example.com","role","ROLE_UNSPECIFIED")));
        verify(google,never()).call(eq("POST"),contains("/members"),anyString(),eq(Map.of("email","joined@example.com","role","ROLE_UNSPECIFIED")));
        assertFalse(result.toString().contains("COHOST"));
    }
    @Test void teacherRevocationRemovesManagedMembership() {
        var course=course(); course.put("students",List.of(new LinkedHashMap<>(Map.of("email","left@example.com","classroomStatus","JOINED","meetStatus","GRANTED","memberName","spaces/test/members/left","meetAllowed",false,"grantAttempted",true)))); store.saveCourse(SUBJECT,course);
        roster(List.of());
        when(google.call(eq("GET"),eq(M+"spaces/test/members"),anyString(),isNull())).thenReturn(Map.of("members",List.of(Map.of("email","left@example.com","name","spaces/test/members/left"))),Map.of("members",List.of()));
        var result=classes.sync(EMAIL,COURSE);
        verify(google).call(eq("DELETE"),eq(M+"spaces/test/members/left"),anyString(),isNull());
        var rows=(List<?>)result.get("students"); var left=(Map<?,?>)rows.get(0);
        assertEquals("LEFT",left.get("classroomStatus")); assertEquals("NOT_GRANTED",left.get("meetStatus")); assertFalse(left.containsKey("memberName"));
    }
    @Test void uncertainGrantIsReconciledWhenStudentLeaves() {
        var course=course(); course.put("students",List.of(new LinkedHashMap<>(Map.of("email","left@example.com","classroomStatus","JOINED","meetStatus","GRANT_FAILED","grantAttempted",true,"meetAllowed",false)))); store.saveCourse(SUBJECT,course);
        roster(List.of());
        when(google.call(eq("GET"),eq(M+"spaces/test/members"),anyString(),isNull())).thenReturn(Map.of("members",List.of(Map.of("email","left@example.com","name","spaces/test/members/left"))),Map.of("members",List.of()));
        classes.sync(EMAIL,COURSE);
        verify(google).call(eq("DELETE"),eq(M+"spaces/test/members/left"),anyString(),isNull());
    }
    @Test void uncertainMeetCreationIsNotRepeatedAutomatically() {
        var course=course(); course.remove("spaceName"); course.remove("meetingUrl"); store.saveCourse(SUBJECT,course); roster(List.of());
        when(google.call(eq("POST"),eq(M+"spaces"),anyString(),any())).thenThrow(new GoogleFailure(502,"GOOGLE_NETWORK","Offline"));
        classes.sync(EMAIL,COURSE); var result=classes.sync(EMAIL,COURSE);
        assertEquals(true,result.get("meetCreationUncertain"));
        verify(google,times(1)).call(eq("POST"),eq(M+"spaces"),anyString(),any());
    }
    @Test void incompletePaginationNeverRevokesAnyGrant() {
        course();
        when(google.call(eq("GET"),eq(M+"spaces/test/members"),anyString(),isNull())).thenReturn(Map.of("nextPageToken","next"));
        when(google.call(eq("GET"),contains("pageToken=next"),anyString(),isNull())).thenThrow(new GoogleFailure(502,"GOOGLE_NETWORK","Offline"));
        assertFalse(((List<?>)classes.sync(EMAIL,COURSE).get("warnings")).isEmpty());
        verify(google,never()).call(eq("DELETE"),anyString(),anyString(),any());
    }
    @Test void grantsFailedAreVisibleAndBlockPrepare() {
        course(); roster(List.of(student("joined@example.com")));
        var explicit=store.course(SUBJECT,COURSE); explicit.put("students",new ArrayList<>(List.of(new LinkedHashMap<>(Map.of("email","joined@example.com","meetAllowed",true,"classroomStatus","JOINED"))))); store.saveCourse(SUBJECT,explicit);
        when(google.call(eq("POST"),eq(M+"spaces/test/members"),anyString(),any())).thenThrow(new GoogleFailure(502,"GOOGLE_403","Policy blocked"));
        var result=classes.sync(EMAIL,COURSE); assertTrue(result.toString().contains("GRANT_FAILED"));
        assertThrows(GoogleFailure.class,()->classes.prepare(EMAIL,COURSE));
    }
    @Test void courseOwnershipDoesNotUseCallerSuppliedCourseIdAlone() {
        course(); assertThrows(GoogleFailure.class,()->store.course("different-sub",COURSE));
    }
    @Test void calendarCreatesRealConferenceAndReusesStableEventId() {
        course(); roster(List.of(student("joined@example.com")));
        var explicit=store.course(SUBJECT,COURSE); explicit.put("students",new ArrayList<>(List.of(new LinkedHashMap<>(Map.of("email","joined@example.com","meetAllowed",true,"classroomStatus","JOINED"))))); store.saveCourse(SUBJECT,explicit);
        var remote=calendarServer("success");
        String request=UUID.randomUUID().toString(), start=java.time.Instant.now().plusSeconds(3600).toString(), end=java.time.Instant.now().plusSeconds(7200).toString();
        classes.schedule(EMAIL,COURSE,request,start,end); classes.schedule(EMAIL,COURSE,request,start,end);
        assertEquals("https://meet.google.com/new-room-aaa",store.course(SUBJECT,COURSE).get("meetingUrl"));
        assertEquals("READY",store.course(SUBJECT,COURSE).get("calendarStatus"));
        assertTrue(remote.toString().contains("joined@example.com"));
        verify(google,never()).call(eq("POST"),eq(M+"spaces"),anyString(),any());
        verify(google,times(1)).call(eq("POST"),contains("calendar/v3"),anyString(),any());
    }
    @SuppressWarnings("unchecked") private Map<String,Object> calendarServer(String state) {
        var remote=new LinkedHashMap<String,Object>();
        when(google.call(eq("POST"),contains("calendar/v3"),anyString(),any())).thenAnswer(call -> {
            assertTrue(call.<String>getArgument(1).contains("conferenceDataVersion=1&sendUpdates=all"));
            Map<String,Object> body=call.getArgument(3);
            assertFalse(body.containsKey("location")); assertTrue(body.containsKey("conferenceData"));
            remote.putAll(body);
            remote.put("htmlLink","https://calendar.google.com/event");
            remote.put("conferenceData",state.equals("success")?Map.of("conferenceSolution",Map.of("key",Map.of("type","hangoutsMeet")),"entryPoints",List.of(Map.of("entryPointType","video","uri","https://meet.google.com/new-room-aaa"))):Map.of("createRequest",Map.of("status",Map.of("statusCode",state))));
            return remote;
        });
        when(google.call(eq("GET"),contains("calendar/v3"),anyString(),isNull())).thenAnswer(call -> remote);
        when(google.call(eq("PATCH"),contains("calendar/v3"),anyString(),any())).thenAnswer(call -> { remote.putAll(call.<Map<String,Object>>getArgument(3)); return remote; });
        return remote;
    }
    private String[] calendarTimes() { return new String[]{java.time.Instant.now().plusSeconds(60).toString(),java.time.Instant.now().plusSeconds(5460).toString()}; }
    @Test void oneClickStartCreatesCalendarForLegacyClassAndReusesRoom() {
        course(); allowStudent("pending@example.com"); calendarServer("success"); String request=UUID.randomUUID().toString();
        assertEquals("READY",classes.start(EMAIL,COURSE,request).get("calendarStatus"));
        assertEquals("READY",classes.start(EMAIL,COURSE,UUID.randomUUID().toString()).get("calendarStatus"));
        verify(google,times(1)).call(eq("POST"),contains("calendar/v3"),anyString(),any());
        verify(google,never()).call(eq("POST"),eq(M+"spaces"),anyString(),any());
    }
    @Test void oneClickStartReusesImminentScheduleAndPollsPendingConference() {
        course(); allowStudent("pending@example.com"); var remote=calendarServer("pending"); var time=calendarTimes();
        classes.schedule(EMAIL,COURSE,UUID.randomUUID().toString(),time[0],time[1]);
        assertEquals("PENDING",classes.start(EMAIL,COURSE,UUID.randomUUID().toString()).get("calendarStatus"));
        remote.put("conferenceData",Map.of("conferenceSolution",Map.of("key",Map.of("type","hangoutsMeet")),"entryPoints",List.of(Map.of("entryPointType","video","uri","https://meet.google.com/new-room-aaa"))));
        assertEquals("READY",classes.start(EMAIL,COURSE,UUID.randomUUID().toString()).get("calendarStatus"));
        verify(google,times(1)).call(eq("POST"),contains("calendar/v3"),anyString(),any());
    }
    @Test void completedLessonStartsFreshCalendarEvenBeforeScheduledEnd() {
        course(); allowStudent("pending@example.com"); calendarServer("success");
        classes.start(EMAIL,COURSE,UUID.randomUUID().toString());
        var saved=store.course(SUBJECT,COURSE);
        @SuppressWarnings("unchecked") var oldEvents=(List<Map<String,Object>>)saved.get("events");
        oldEvents.get(0).remove("meetingUrl"); store.saveCourse(SUBJECT,saved); // Previous build stored the URL only on the course.
        var history=com.google.gson.JsonParser.parseString("[{\"meetingUrl\":\"https://meet.google.com/new-room-aaa\",\"status\":\"COMPLETED\"}]").getAsJsonArray();
        when(classrooms.getClassroomHistory(null)).thenReturn(history);
        classes.start(EMAIL,COURSE,UUID.randomUUID().toString());
        verify(google,times(2)).call(eq("POST"),contains("calendar/v3"),anyString(),any());
    }
    @Test void activeLessonAfterScheduledEndStillUsesSameRoom() {
        course(); allowStudent("pending@example.com"); var remote=calendarServer("success");
        classes.start(EMAIL,COURSE,UUID.randomUUID().toString());
        var saved=store.course(SUBJECT,COURSE);
        @SuppressWarnings("unchecked") var events=(List<Map<String,Object>>)saved.get("events");
        events.get(0).put("end",java.time.Instant.now().minusSeconds(60).toString());
        remote.put("end",Map.of("dateTime",events.get(0).get("end")));
        // Remote event must agree with saved operation, even for an overtime live call.
        when(classrooms.getActiveClassroom()).thenReturn(com.google.gson.JsonParser.parseString("{\"status\":\"ONGOING\",\"meetingUrl\":\"https://meet.google.com/new-room-aaa\"}").getAsJsonObject());
        store.saveCourse(SUBJECT,saved);
        assertEquals("READY",classes.start(EMAIL,COURSE,UUID.randomUUID().toString()).get("calendarStatus"));
        verify(google,times(1)).call(eq("POST"),contains("calendar/v3"),anyString(),any());
    }
    @Test void calendarRecoversExistingMicrosecondOperationWhenGoogleReturnsWholeSeconds() {
        course(); roster(List.of()); allowStudent("pending@example.com"); var remote=calendarServer("success");
        var time=calendarTimes(); String request=UUID.randomUUID().toString();
        classes.schedule(EMAIL,COURSE,request,time[0],time[1]);
        var saved=store.course(SUBJECT,COURSE);
        @SuppressWarnings("unchecked") var operations=(List<Map<String,Object>>)saved.get("events");
        // Emulate the operation saved by the previous Windows build before Google normalizes it.
        operations.get(0).put("start",java.time.Instant.parse(time[0]).truncatedTo(java.time.temporal.ChronoUnit.SECONDS).plusNanos(46_980_000).toString());
        operations.get(0).put("end",java.time.Instant.parse(time[1]).truncatedTo(java.time.temporal.ChronoUnit.SECONDS).plusNanos(46_980_000).toString());
        saved.put("calendarStatus","VERIFY_FAILED"); saved.remove("calendarCreated"); saved.remove("meetingUrl"); store.saveCourse(SUBJECT,saved);
        remote.put("start",Map.of("dateTime",java.time.Instant.parse(time[0]).truncatedTo(java.time.temporal.ChronoUnit.SECONDS).atOffset(java.time.ZoneOffset.ofHours(7)).toString()));
        remote.put("end",Map.of("dateTime",java.time.Instant.parse(time[1]).truncatedTo(java.time.temporal.ChronoUnit.SECONDS).toString()));
        assertEquals("READY",classes.prepare(EMAIL,COURSE).get("calendarStatus"));
        assertEquals("READY",classes.schedule(EMAIL,COURSE,request,time[0],time[1]).get("calendarStatus"));
        verify(google,times(1)).call(eq("POST"),contains("calendar/v3"),anyString(),any());
        // Real time changes must still be rejected; this is not a broad tolerance window.
        remote.put("start",Map.of("dateTime",java.time.Instant.parse(time[0]).truncatedTo(java.time.temporal.ChronoUnit.SECONDS).plusSeconds(1).toString()));
        assertThrows(GoogleFailure.class,()->classes.prepare(EMAIL,COURSE));
    }
    @Test void calendarInvitesPendingClassroomStudentAndSyncDoesNotCreateAnotherRoom() {
        course(); roster(List.of()); allowStudent("pending@example.com"); calendarServer("success");
        var time=calendarTimes(); var result=classes.schedule(EMAIL,COURSE,UUID.randomUUID().toString(),time[0],time[1]);
        assertTrue(result.toString().contains("CALENDAR_INVITED"));
        assertEquals(result.get("meetingUrl"),classes.prepare(EMAIL,COURSE).get("meetingUrl"));
        verify(google,never()).call(eq("POST"),eq(M+"spaces/test/members"),anyString(),any());
    }
    @Test void calendarPendingBlocksStartAndSyncFinishesWithoutDuplicateEvent() {
        course(); roster(List.of()); allowStudent("pending@example.com"); var remote=calendarServer("pending");
        var time=calendarTimes(); classes.schedule(EMAIL,COURSE,UUID.randomUUID().toString(),time[0],time[1]);
        assertFalse(store.course(SUBJECT,COURSE).containsKey("meetingUrl"));
        assertThrows(GoogleFailure.class,()->classes.prepare(EMAIL,COURSE));
        remote.put("conferenceData",Map.of("conferenceSolution",Map.of("key",Map.of("type","hangoutsMeet")),"entryPoints",List.of(Map.of("entryPointType","video","uri","https://meet.google.com/new-room-aaa"))));
        assertEquals("READY",classes.prepare(EMAIL,COURSE).get("calendarStatus"));
        verify(google,times(1)).call(eq("POST"),contains("calendar/v3"),anyString(),any());
    }
    @Test void calendarFailureDoesNotFallBackToOldMeet() {
        course(); roster(List.of()); allowStudent("pending@example.com"); calendarServer("failure"); var time=calendarTimes();
        var result=classes.schedule(EMAIL,COURSE,UUID.randomUUID().toString(),time[0],time[1]);
        assertEquals("FAILED",result.get("calendarStatus")); assertFalse(result.containsKey("meetingUrl"));
        assertThrows(GoogleFailure.class,()->classes.prepare(EMAIL,COURSE));
    }
    @Test void calendarEmailChangesPatchSameEventAndPreserveUnmanagedGuest() {
        course(); roster(List.of()); allowStudent("pending@example.com"); var remote=calendarServer("success"); var time=calendarTimes();
        classes.schedule(EMAIL,COURSE,UUID.randomUUID().toString(),time[0],time[1]);
        remote.put("attendees",new ArrayList<>(List.of(Map.of("email","pending@example.com"),Map.of("email","external@example.com","responseStatus","accepted"))));
        var result=classes.setMeetAccess(EMAIL,COURSE,"pending@example.com",false);
        assertFalse(remote.get("attendees").toString().contains("pending@example.com"));
        assertTrue(remote.get("attendees").toString().contains("external@example.com"));
        assertEquals("READY",result.get("calendarStatus"));
        verify(google,times(1)).call(eq("POST"),contains("calendar/v3"),anyString(),any());
    }
    @Test void calendarTimeoutIsRecoveredByReadingSameId() {
        course(); roster(List.of()); allowStudent("pending@example.com"); calendarServer("success");
        var time=calendarTimes(); String request=UUID.randomUUID().toString();
        doAnswer(call -> {
            Map<String,Object> body=call.getArgument(3);
            var event=new LinkedHashMap<String,Object>(body);
            event.put("conferenceData",Map.of("conferenceSolution",Map.of("key",Map.of("type","hangoutsMeet")),"entryPoints",List.of(Map.of("entryPointType","video","uri","https://meet.google.com/new-room-aaa"))));
            when(google.call(eq("GET"),contains("calendar/v3"),anyString(),isNull())).thenReturn(event);
            throw new GoogleFailure(502,"GOOGLE_NETWORK","Timeout");
        }).when(google).call(eq("POST"),contains("calendar/v3"),anyString(),any());
        assertThrows(GoogleFailure.class,()->classes.schedule(EMAIL,COURSE,request,time[0],time[1]));
        assertEquals("READY",classes.schedule(EMAIL,COURSE,request,time[0],time[1]).get("calendarStatus"));
        verify(google,times(1)).call(eq("POST"),contains("calendar/v3"),anyString(),any());
    }
    @Test void calendarForeignEventAndIncompleteAttendeesNeverBecomeReady() {
        course(); roster(List.of()); allowStudent("pending@example.com"); var remote=calendarServer("success"); var time=calendarTimes();
        classes.schedule(EMAIL,COURSE,UUID.randomUUID().toString(),time[0],time[1]);
        remote.put("attendeesOmitted",true);
        assertThrows(GoogleFailure.class,()->classes.prepare(EMAIL,COURSE));
        remote.remove("attendeesOmitted"); remote.put("extendedProperties",Map.of());
        assertThrows(GoogleFailure.class,()->classes.prepare(EMAIL,COURSE));
    }
    @Test void localSessionAndOriginAreRequired() throws Exception {
        mvc.perform(get("/api/integrations/google/status").header("X-Google-Teacher-Email",EMAIL)).andExpect(status().isUnauthorized());
        mvc.perform(post("/api/integrations/google/connect").header("X-Companion-Token",companionToken).header("X-Google-Teacher-Email",EMAIL)
            .header("Origin","https://external.example").contentType("application/json").content("{\"email\":\"teacher@example.com\"}"))
            .andExpect(status().isForbidden());
        mvc.perform(get("/api/integrations/google/status").header("X-Companion-Token",companionToken).header("X-Google-Teacher-Email",EMAIL))
            .andExpect(status().isOk()).andExpect(jsonPath("$.connected").value(true)).andExpect(jsonPath("$.access_token").doesNotExist());
    }
}
