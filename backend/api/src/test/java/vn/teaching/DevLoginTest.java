package vn.teaching;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest(properties = {
        "app.auth.dev-login.enabled=true",
        "exam.admin.email=teacher.dev@hocluc.local",
        "exam.admin.password=HocLucDev2026!"
})
@AutoConfigureMockMvc
@ActiveProfiles("dev")
class DevLoginTest {
    @Autowired private MockMvc mockMvc;

    @Test
    void devLoginReturnsSharedAdminSession() throws Exception {
        mockMvc.perform(post("/api/auth/dev-login"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.token").isNotEmpty())
                .andExpect(jsonPath("$.user.role").value("ADMIN"))
                .andExpect(jsonPath("$.user.email").value("teacher.dev@hocluc.local"));
    }
}
