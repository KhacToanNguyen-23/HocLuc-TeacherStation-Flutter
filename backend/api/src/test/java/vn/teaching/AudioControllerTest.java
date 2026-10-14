package vn.teaching;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.test.web.servlet.MockMvc;
import vn.teaching.service.AudioRuntimeService;
import java.util.Map;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
class AudioControllerTest {
    @Autowired MockMvc mvc;
    @Autowired String companionToken;
    @MockBean AudioRuntimeService runtime;
    @Test void noAudioControlWithoutCompanionSession() throws Exception {
        mvc.perform(get("/api/audio/status")).andExpect(status().isUnauthorized());
        verifyNoInteractions(runtime);
    }
    @Test void statusDoesNotLoadModelsOrStartProcess() throws Exception {
        when(runtime.status()).thenReturn(Map.of("installed",true,"modelsLoaded",false));
        mvc.perform(get("/api/audio/status").header("X-Companion-Token",companionToken)
            .with(r->{r.setServerName("127.0.0.1");r.setLocalAddr("127.0.0.1");return r;}))
            .andExpect(status().isOk()).andExpect(jsonPath("$.modelsLoaded").value(false));
        verify(runtime).status();verifyNoMoreInteractions(runtime);
    }
    @Test void remoteOriginCannotStartAudioWorker() throws Exception {
        mvc.perform(post("/api/audio/connect").header("X-Companion-Token",companionToken)
            .header("Origin","https://example.invalid").contentType("application/json").content("{}")
            .with(r->{r.setServerName("127.0.0.1");r.setLocalAddr("127.0.0.1");return r;}))
            .andExpect(status().isBadRequest());
        verifyNoInteractions(runtime);
    }
}
