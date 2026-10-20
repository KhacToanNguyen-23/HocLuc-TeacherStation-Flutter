package vn.teaching.exam;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.web.servlet.MockMvc;
import vn.teaching.modules.auth.service.AuthService;
import java.util.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest(properties={"app.auth.google.client-id=test-client.apps.googleusercontent.com","app.auth.admin-emails=google-admin@identity.test"})
@AutoConfigureMockMvc
class SharedIdentityTest {
    @Autowired ExamAuth auth; @Autowired AuthService appAuth; @Autowired GoogleOAuthService google; @Autowired MockMvc mvc;
    @MockBean GoogleOAuthProvider provider;
    @Test void existingAppPasswordSessionAuthorizesExamDataWithStableIdentity() throws Exception {
        String email=UUID.randomUUID()+"@identity.test";
        var registered=appAuth.register(email,"123456","existing-password"); assertTrue(registered.isSuccess());
        var login=appAuth.login(email,"existing-password");assertEquals(registered.getUser().get("id"),login.getUser().get("id"));
        mvc.perform(get("/api/exams/dashboard").header("Authorization","Bearer "+login.getToken())).andExpect(status().isOk());
        mvc.perform(get("/api/auth/session").header("Authorization","Bearer "+login.getToken())).andExpect(status().isOk()).andExpect(jsonPath("$.id").value(registered.getUser().get("id")));
        assertFalse(appAuth.login(email,"wrong-password").isSuccess());
    }
    @Test void googleCallbackAndPollAreBoundToStateProofAndOneUse() {
        when(provider.exchange(anyString(),anyString(),anyString())).thenReturn(new GoogleOAuthProvider.Identity("subject-"+UUID.randomUUID(),UUID.randomUUID()+"@identity.test","Google teacher","real-provider-token"));
        var flow=google.start();assertTrue(flow.get("authorizationUrl").toString().contains("code_challenge_method=S256"));
        assertThrows(ExamException.class,()->google.poll(flow.get("state").toString(),"wrong-proof"));
        google.callback(flow.get("state").toString(),"provider-code",null);
        var session=google.poll(flow.get("state").toString(),flow.get("pollToken").toString());assertEquals("COMPLETE",session.get("status"));
        assertEquals("TEACHER",((ExamModels.Account)session.get("user")).role());assertEquals("real-provider-token",session.get("googleAccessToken"));
        assertThrows(ExamException.class,()->google.poll(flow.get("state").toString(),flow.get("pollToken").toString()));
        assertThrows(ExamException.class,()->google.callback(flow.get("state").toString(),"provider-code",null));
    }
    @Test void verifiedGoogleIdentityKeepsOwnershipOfExistingPasswordAccount() {
        String email=UUID.randomUUID()+"@identity.test",subject=UUID.randomUUID().toString();
        var password=appAuth.register(email,"123456","password-for-existing-app");
        when(provider.exchange(anyString(),anyString(),anyString())).thenReturn(new GoogleOAuthProvider.Identity(subject,email,"Google teacher","provider-token"));
        var flow=google.start();google.callback(flow.get("state").toString(),"code",null);
        var session=google.poll(flow.get("state").toString(),flow.get("pollToken").toString());
        assertEquals(password.getUser().get("id"),((ExamModels.Account)session.get("user")).id());
        assertEquals(((ExamModels.Account)session.get("user")).id(),((ExamModels.Account)auth.google(subject,email,"Google teacher").get("user")).id());
    }
    @Test void googleAdminGrantComesOnlyFromServerAllowlist() {
        assertEquals("ADMIN",((ExamModels.Account)auth.google("configured-admin-subject","google-admin@identity.test","Admin").get("user")).role());
        assertEquals("TEACHER",((ExamModels.Account)auth.google("ordinary-"+UUID.randomUUID(),UUID.randomUUID()+"@identity.test","Admin").get("user")).role());
    }
    @Test void fabricatedWebviewMarkerCannotAuthorizePrivateExamApi() throws Exception {
        mvc.perform(get("/api/exams/dashboard").header("Authorization","Bearer webview2_authenticated_google_session")).andExpect(status().isUnauthorized());
        mvc.perform(post("/api/exams/auth/login").contentType("application/json").content("{\"email\":\"teacher@gmail.com\",\"password\":\"anything\"}")).andExpect(status().isUnauthorized());
    }
    @Test void canceledCallbackAndMissingConfigDoNotCreateSuccessfulSession() {
        var flow=google.start();google.callback(flow.get("state").toString(),null,"access_denied");
        assertThrows(ExamException.class,()->google.poll(flow.get("state").toString(),flow.get("pollToken").toString()));
        verifyNoInteractions(provider);
        assertThrows(ExamException.class,()->new GoogleOAuthService(auth,provider,"","http://127.0.0.1/callback").start());
        assertThrows(ExamException.class,()->google.poll(null,null));
    }
}
