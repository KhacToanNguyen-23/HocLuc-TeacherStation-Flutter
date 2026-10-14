package vn.teaching;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
class GoogleOAuthControllerTest {
    @Autowired MockMvc mvc;
    @Autowired String companionToken;

    @Test
    void oauthRequiresCompanionTokenAndRejectsRemoteWebsiteOrigins() throws Exception {
        mvc.perform(post("/api/google/oauth/start").contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isUnauthorized());
        mvc.perform(post("/api/google/oauth/status").header("X-Companion-Token", companionToken)
                        .header("Origin", "https://example.com").contentType(MediaType.APPLICATION_JSON).content("{\"flowId\":\"unknown\"}"))
                .andExpect(status().isForbidden());
        mvc.perform(post("/api/google/oauth/status").header("X-Companion-Token", companionToken)
                        .header("Origin", "http://localhost:4173").contentType(MediaType.APPLICATION_JSON).content("{\"flowId\":\"unknown\"}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.status").value("EXPIRED"));
    }

    @Test
    void roomCreationRejectsLegacyTokensWithoutAnOauthGrant() throws Exception {
        mvc.perform(post("/api/classroom/create").header("X-Companion-Token", companionToken)
                        .contentType(MediaType.APPLICATION_JSON).content("{\"accessToken\":\"webview2_authenticated_google_session\"}"))
                .andExpect(status().isOk()).andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.requiresGoogleReconnect").value(true));
    }
}
