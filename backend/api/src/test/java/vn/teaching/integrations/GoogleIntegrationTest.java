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
    static final String EMAIL="teacher@example.com", SUBJECT="teacher-sub", COURSE="11111111-1111-4111-8111-111111111111";
    static final String C="https://classroom.googleapis.com/v1/", M="https://meet.googleapis.com/v2/";
    @BeforeEach void setup() {
        jdbc.update("DELETE FROM exam_platform.google_courses"); jdbc.update("DELETE FROM exam_platform.google_connections");
        reset(google);
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
        when(google.call(eq("GET"),eq(M+"spaces/test/members"),anyString(),isNull())).thenReturn(Map.of());
        when(google.call(eq("GET"),eq(M+"spaces/test"),anyString(),isNull())).thenReturn(Map.of("config",Map.of("accessType","TRUSTED")));
    }
    private Map<String,Object> student(String email) { return Map.of("profile",Map.of("emailAddress",email,"name",Map.of("fullName","Student"))); }
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
        verify(google,times(1)).call(eq("POST"),eq(M+"spaces"),anyString(),any());
        assertEquals(1,((List<?>)result.get("students")).size());
        assertEquals("https://meet.google.com/abc-defg-hij",result.get("meetingUrl"));
        verify(google).call(eq("POST"),eq(C+"courses"),anyString(),argThat(body -> "PROVISIONED".equals(((Map<?,?>)body).get("courseState"))));
    }
    @Test void activationDeniedDefersInvitationsUntilTeacherAccepts() {
        when(google.call(eq("POST"),eq(C+"courses"),anyString(),any())).thenReturn(Map.of("id","google-course","courseState","PROVISIONED","alternateLink","https://classroom.google.com/c/test"));
        when(google.call(eq("PATCH"),eq(C+"courses/google-course?updateMask=courseState"),anyString(),any())).thenThrow(new GoogleFailure(502,"GOOGLE_403","Activation denied"));
        var result=classes.create(EMAIL,COURSE,"Toán 12A","",List.of("an@example.com"));
        assertEquals("PROVISIONED",result.get("classroomState")); assertTrue(result.get("warnings").toString().contains("Chưa gửi lời mời"));
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
    @Test void onlyAcceptedStudentsGetOrdinaryMeetMembership() {
        var course=course(); course.put("students",List.of(new LinkedHashMap<>(Map.of("email","pending@example.com","classroomStatus","INVITED","meetStatus","NOT_GRANTED")))); store.saveCourse(SUBJECT,course);
        roster(List.of(student("joined@example.com")));
        when(google.call(eq("POST"),eq(M+"spaces/test/members"),anyString(),eq(Map.of("email","joined@example.com","role","ROLE_UNSPECIFIED")))).thenReturn(Map.of("name","spaces/test/members/joined","email","joined@example.com"));
        var result=classes.sync(EMAIL,COURSE);
        assertTrue(result.toString().contains("GRANTED"));
        verify(google,never()).call(eq("POST"),contains("/members"),anyString(),eq(Map.of("email","pending@example.com","role","ROLE_UNSPECIFIED")));
        assertFalse(result.toString().contains("COHOST"));
    }
    @Test void departedStudentLosesManagedGrant() {
        var course=course(); course.put("students",List.of(new LinkedHashMap<>(Map.of("email","left@example.com","classroomStatus","JOINED","meetStatus","GRANTED","memberName","spaces/test/members/left")))); store.saveCourse(SUBJECT,course);
        roster(List.of());
        when(google.call(eq("GET"),eq(M+"spaces/test/members"),anyString(),isNull())).thenReturn(Map.of("members",List.of(Map.of("email","left@example.com","name","spaces/test/members/left"))));
        var result=classes.sync(EMAIL,COURSE);
        verify(google).call(eq("DELETE"),eq(M+"spaces/test/members/left"),anyString(),isNull());
        var rows=(List<?>)result.get("students"); var left=(Map<?,?>)rows.get(0);
        assertEquals("LEFT",left.get("classroomStatus")); assertEquals("NOT_GRANTED",left.get("meetStatus")); assertFalse(left.containsKey("memberName"));
    }
    @Test void uncertainGrantIsReconciledWhenStudentLeaves() {
        var course=course(); course.put("students",List.of(new LinkedHashMap<>(Map.of("email","left@example.com","classroomStatus","JOINED","meetStatus","GRANT_FAILED","grantAttempted",true)))); store.saveCourse(SUBJECT,course);
        roster(List.of());
        when(google.call(eq("GET"),eq(M+"spaces/test/members"),anyString(),isNull())).thenReturn(Map.of("members",List.of(Map.of("email","left@example.com","name","spaces/test/members/left"))));
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
        when(google.call(eq("GET"),eq(C+"courses/google-course/students"),anyString(),isNull())).thenReturn(Map.of("nextPageToken","next"));
        when(google.call(eq("GET"),contains("pageToken=next"),anyString(),isNull())).thenThrow(new GoogleFailure(502,"GOOGLE_NETWORK","Offline"));
        assertThrows(GoogleFailure.class,()->classes.sync(EMAIL,COURSE));
        verify(google,never()).call(eq("DELETE"),anyString(),anyString(),any());
    }
    @Test void grantsFailedAreVisibleAndBlockPrepare() {
        course(); roster(List.of(student("joined@example.com")));
        when(google.call(eq("POST"),eq(M+"spaces/test/members"),anyString(),any())).thenThrow(new GoogleFailure(502,"GOOGLE_403","Policy blocked"));
        var result=classes.sync(EMAIL,COURSE); assertTrue(result.toString().contains("GRANT_FAILED"));
        assertThrows(GoogleFailure.class,()->classes.prepare(EMAIL,COURSE));
    }
    @Test void courseOwnershipDoesNotUseCallerSuppliedCourseIdAlone() {
        course(); assertThrows(GoogleFailure.class,()->store.course("different-sub",COURSE));
    }
    @Test void calendarUsesExistingRoomAndStableEventId() {
        course(); roster(List.of(student("joined@example.com")));
        when(google.call(eq("POST"),eq(M+"spaces/test/members"),anyString(),any())).thenReturn(Map.of("name","spaces/test/members/joined","email","joined@example.com"));
        when(google.call(eq("POST"),contains("calendar/v3"),anyString(),any())).thenAnswer(call -> { var body=(Map<?,?>)call.getArgument(3); assertEquals("https://meet.google.com/abc-defg-hij",body.get("location")); assertFalse(body.containsKey("conferenceData")); return Map.of("id",body.get("id"),"htmlLink","https://calendar.google.com/event"); });
        String request=UUID.randomUUID().toString(), start=java.time.Instant.now().plusSeconds(3600).toString(), end=java.time.Instant.now().plusSeconds(7200).toString();
        classes.schedule(EMAIL,COURSE,request,start,end); classes.schedule(EMAIL,COURSE,request,start,end);
        verify(google,times(1)).call(eq("POST"),contains("calendar/v3"),anyString(),any());
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
