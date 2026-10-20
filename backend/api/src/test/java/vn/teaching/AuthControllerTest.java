package vn.teaching;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.context.ActiveProfiles;
import vn.teaching.modules.auth.dto.LoginRequest;
import vn.teaching.modules.auth.dto.OtpAuthRequest;
import vn.teaching.modules.auth.dto.RegisterRequest;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest(properties = "app.auth.dev-login.enabled=true")
@AutoConfigureMockMvc
@ActiveProfiles("prod")
public class AuthControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @Test
    void devLoginIsUnavailableOutsideDevProfile() throws Exception {
        mockMvc.perform(post("/api/auth/dev-login"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.success").value(false));
    }

    @Test
    void testSendOtpSuccess() throws Exception {
        OtpAuthRequest request = new OtpAuthRequest();
        request.setTarget("+84987654321");
        request.setType("login");

        mockMvc.perform(post("/api/auth/otp/send")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.message").isNotEmpty());
    }

    @Test
    void testSendOtpBlankTarget() throws Exception {
        OtpAuthRequest request = new OtpAuthRequest();
        request.setTarget("   ");
        request.setType("login");

        mockMvc.perform(post("/api/auth/otp/send")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false));
    }

    @Test
    void testVerifyOtpDevBypass() throws Exception {
        OtpAuthRequest sendReq = new OtpAuthRequest();
        sendReq.setTarget("teacher@example.com");
        sendReq.setType("signup");

        mockMvc.perform(post("/api/auth/otp/send")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(sendReq)))
                .andExpect(status().isOk());

        OtpAuthRequest verifyReq = new OtpAuthRequest();
        verifyReq.setTarget("teacher@example.com");
        verifyReq.setType("signup");
        verifyReq.setOtp("123456");
        verifyReq.setName("Thầy Cô Giáo");

        mockMvc.perform(post("/api/auth/otp/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(verifyReq)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.token").isNotEmpty())
                .andExpect(jsonPath("$.user.email").value("teacher@example.com"));
    }

    @Test
    void testVerifyOtpInvalidCode() throws Exception {
        OtpAuthRequest verifyReq = new OtpAuthRequest();
        verifyReq.setTarget("teacher@example.com");
        verifyReq.setType("login");
        verifyReq.setOtp("000000");

        mockMvc.perform(post("/api/auth/otp/verify")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(verifyReq)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false));
    }

    @Test
    void testRegisterAndLoginEndpoint() throws Exception {
        RegisterRequest regReq = new RegisterRequest();
        regReq.setTarget("gv.test@hocluc.vn");
        regReq.setOtp("123456");
        regReq.setPassword("matkhau123");

        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(regReq)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.token").isNotEmpty())
                .andExpect(jsonPath("$.user.email").value("gv.test@hocluc.vn"));

        LoginRequest loginReq = new LoginRequest();
        loginReq.setIdentifier("gv.test@hocluc.vn");
        loginReq.setPassword("matkhau123");

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(loginReq)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.token").isNotEmpty());
    }

    @Test
    void testLoginValidationBlankFields() throws Exception {
        LoginRequest req = new LoginRequest("", "");

        mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.message").isNotEmpty())
                .andExpect(jsonPath("$.details").isArray());
    }

    @Test
    void testRegisterValidationShortPassword() throws Exception {
        RegisterRequest req = new RegisterRequest("teacher@example.com", "123456", "123");

        mockMvc.perform(post("/api/auth/register")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(req)))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.message").value("Mật khẩu phải có ít nhất 6 ký tự."));
    }
}
