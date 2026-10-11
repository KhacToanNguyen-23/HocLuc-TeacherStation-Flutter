package vn.teaching;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import vn.teaching.model.OtpAuthRequest;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
public class AuthControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

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
    void testDemoLoginEndpoint() throws Exception {
        mockMvc.perform(post("/api/auth/demo")
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.token").isNotEmpty())
                .andExpect(jsonPath("$.user.email").value("khactoan2233@gmail.com"))
                .andExpect(jsonPath("$.user.name").value("Thầy Khắc Toàn (Giáo viên Demo)"));
    }
}
