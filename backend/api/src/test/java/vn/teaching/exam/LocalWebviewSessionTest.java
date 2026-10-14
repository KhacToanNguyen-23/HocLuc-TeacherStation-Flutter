package vn.teaching.exam;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(webEnvironment=SpringBootTest.WebEnvironment.RANDOM_PORT, properties={"server.address=127.0.0.1", "app.auth.google.client-id=", "app.auth.webview-local.enabled=true", "app.auth.admin-emails=local-admin@identity.test"})
@AutoConfigureMockMvc
class LocalWebviewSessionTest {
    @Autowired MockMvc mvc;
    @Autowired ExamAuth auth;
    @Autowired ExamRepository repo;
    @Autowired com.fasterxml.jackson.databind.ObjectMapper json;
    @Autowired String companionToken;
    @Autowired org.springframework.boot.test.web.client.TestRestTemplate http;

    @Test void realHttpHandshakeLoadsExamDashboardWithoutGoogleCredentials() {
        var bootstrap=http.getForObject("/api/bootstrap",Map.class);
        var headers=new org.springframework.http.HttpHeaders();
        headers.set("X-Companion-Token",bootstrap.get("token").toString());
        var body=Map.of("email",UUID.randomUUID()+"@identity.test","name","HTTP teacher");
        var local=http.postForEntity("/api/auth/google/webview-session",new org.springframework.http.HttpEntity<>(body,headers),Map.class);
        assertEquals(200,local.getStatusCode().value());
        var bearer=new org.springframework.http.HttpHeaders();
        bearer.setBearerAuth(local.getBody().get("token").toString());
        var dashboard=http.exchange("/api/exams/dashboard",org.springframework.http.HttpMethod.GET,new org.springframework.http.HttpEntity<>(bearer),Map.class);
        assertEquals(200,dashboard.getStatusCode().value());
        var admin=http.exchange("/api/exams/admin/jobs",org.springframework.http.HttpMethod.GET,new org.springframework.http.HttpEntity<>(bearer),Map.class);
        assertEquals(403,admin.getStatusCode().value());
    }

    private Map<?,?> local(String email) throws Exception {
        String content=mvc.perform(post("/api/auth/google/webview-session")
                .header("X-Companion-Token",companionToken).contentType("application/json")
                .content(repo.json(Map.of("email",email,"name","Giáo viên WebView"))))
                .andExpect(status().isOk()).andExpect(header().string("Cache-Control","no-store"))
                .andExpect(jsonPath("$.user.role").value("TEACHER")).andReturn().getResponse().getContentAsString();
        return json.readValue(content,Map.class);
    }

    @Test void developProfileGetsPersistentTeacherWorkspaceWithoutOAuthConfig() throws Exception {
        String email=UUID.randomUUID()+"@identity.test";
        var first=local(email); var second=local(email.toUpperCase(Locale.ROOT));
        assertEquals(((Map<?,?>)first.get("user")).get("id"),((Map<?,?>)second.get("user")).get("id"));
        mvc.perform(get("/api/exams/dashboard").header("Authorization","Bearer "+first.get("token"))).andExpect(status().isOk());
        mvc.perform(get("/api/exams/admin/jobs").header("Authorization","Bearer "+first.get("token"))).andExpect(status().isForbidden());
        auth.logout("Bearer "+first.get("token"));
        mvc.perform(get("/api/exams/dashboard").header("Authorization","Bearer "+first.get("token"))).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/exams/dashboard").header("Authorization","Bearer "+second.get("token"))).andExpect(status().isOk());
    }

    @Test void localProfileCannotClaimPasswordAccountOrGoogleAdminAllowlist() throws Exception {
        String email="local-admin@identity.test";
        var existing=auth.registerApp(email,"password-for-existing-account","Password teacher");
        var result=local(email);
        assertNotEquals(((ExamModels.Account)existing.get("user")).id(),((Map<?,?>)result.get("user")).get("id"));
        assertEquals("TEACHER",((Map<?,?>)result.get("user")).get("role"));
    }

    @Test void bridgeRejectsMissingProofRemoteClientsAndForeignOrigins() throws Exception {
        String body=repo.json(Map.of("email","teacher@identity.test","name","Teacher"));
        mvc.perform(post("/api/auth/google/webview-session").contentType("application/json").content(body)).andExpect(status().isForbidden());
        mvc.perform(post("/api/auth/google/webview-session").header("X-Companion-Token","wrong").contentType("application/json").content(body)).andExpect(status().isForbidden());
        mvc.perform(post("/api/auth/google/webview-session").header("X-Companion-Token",companionToken)
                .header("Origin","https://foreign.example").contentType("application/json").content(body)).andExpect(status().isForbidden());
        mvc.perform(post("/api/auth/google/webview-session").header("X-Companion-Token",companionToken)
                .with(req->{req.setRemoteAddr("192.0.2.1");return req;}).contentType("application/json").content(body)).andExpect(status().isForbidden());
        mvc.perform(post("/api/auth/google/webview-session").header("X-Companion-Token",companionToken)
                .with(req->{req.setServerName("foreign.example");return req;}).contentType("application/json").content(body)).andExpect(status().isForbidden());
        mvc.perform(post("/api/auth/google/webview-session").header("X-Companion-Token",companionToken)
                .header("Origin","http://127.0.0.1:4173").contentType("application/json").content(body)).andExpect(status().isOk());
    }

    @Test void disabledOrNonLoopbackServerCannotEnableCompatibility() {
        var request=new org.springframework.mock.web.MockHttpServletRequest();
        request.addHeader("X-Companion-Token",companionToken);
        request.setLocalAddr("127.0.0.1");request.setRemoteAddr("127.0.0.1");request.setServerName("localhost");
        var input=Map.of("email","teacher@identity.test","name","Teacher");
        assertThrows(ExamException.class,()->new LocalWebviewSessionController(auth,companionToken,"0.0.0.0",true).session(request,input));
        assertThrows(ExamException.class,()->new LocalWebviewSessionController(auth,companionToken,"127.0.0.1",false).session(request,input));
    }
}
